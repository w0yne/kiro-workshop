---
title: Production-Ready Configuration Guide
description: CloudFront + EC2 + Nginx + Vite 生产环境配置最佳实践
version: 1.0.0
tags: [cloudfront, nginx, vite, production, deployment, proxy]
---

# Production-Ready Configuration Guide

本文档总结了在 CloudFront + EC2 + Nginx + Vite 环境下部署前端应用的完整配置经验和最佳实践。

## 架构概述

```
CloudFront (HTTPS) → EC2 (Nginx) → Static Files / Backend API
     │                    │              │
     └─ /proxy/5173/      ├─ /var/www/html/proxy/5173/ (Static)
                          └─ /api/ → localhost:8000 (Backend)
```

## 核心问题和解决方案

### 1. Vite 开发服务器 vs 生产静态文件

**问题**：Vite 开发服务器不适合通过代理路径访问，会出现资源加载错误。

**错误现象**：
```
GET https://domain.com/@vite/client net::ERR_ABORTED 404
GET https://domain.com/src/main.tsx net::ERR_ABORTED 404
GET https://domain.com/@react-refresh net::ERR_ABORTED 404
```

**解决方案**：使用生产构建 + 静态文件服务

#### Vite 配置 (vite.config.ts)

```typescript
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import path from 'path'

export default defineConfig({
  plugins: [react(), tailwindcss()],
  
  // 动态设置 base URL
  base: process.env.VITE_BASE_URL || '/',
  
  resolve: {
    alias: { '@': path.resolve(__dirname, './src') },
  },
  
  server: {
    port: 5173,
    host: '0.0.0.0',  // 允许外部访问
    allowedHosts: ['your-cloudfront-domain.cloudfront.net'],
    proxy: {
      '/api': {
        target: 'http://localhost:8000',
        changeOrigin: true,
      },
    },
  },
})
```

#### TypeScript 配置修复

**问题**：`verbatimModuleSyntax: true` 导致构建失败

**解决方案**：修改 `tsconfig.app.json`

```json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": { "@/*": ["./src/*"] },
    "verbatimModuleSyntax": false,  // 关键修改
    "noUnusedLocals": false,        // 构建时放宽限制
    "noUnusedParameters": false
  }
}
```

#### 构建和部署

```bash
# 构建生产版本
VITE_BASE_URL=/proxy/5173/ npm run build

# 部署到 nginx 目录
sudo mkdir -p /var/www/html/proxy/5173
sudo cp -r dist/* /var/www/html/proxy/5173/
```

### 2. Nginx 配置最佳实践

#### 完整配置示例

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name your-domain.cloudfront.net;
    
    # 禁止访问敏感端口
    location ^~ /proxy/8080/ {
        return 403;
    }

    # API 代理到后端
    location /api/ {
        proxy_pass http://127.0.0.1:8000/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # 关键：禁用缓存和缓冲
        proxy_buffering off;
        proxy_cache off;
        
        # SSE 支持
        proxy_set_header Connection '';
        proxy_http_version 1.1;
        chunked_transfer_encoding off;
    }

    # 前端静态文件（优先级最高）
    location ^~ /proxy/5173/ {
        alias /var/www/html/proxy/5173/;
        try_files $uri $uri/ /proxy/5173/index.html;
        
        # 防止缓存问题
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        add_header Expires "0";
    }

    # 动态端口代理（排除 5173）
    location ~ ^/proxy/(?!5173)(\d+)/(.*)$ {
        proxy_pass http://127.0.0.1:$1/$2;
        proxy_set_header Host $host;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection upgrade;
        proxy_set_header Accept-Encoding gzip;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # 根路径代理（排除 5173）
    location ~ ^/proxy/(?!5173)(\d+)/?$ {
        proxy_pass http://127.0.0.1:$1/;
        proxy_set_header Host $host;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection upgrade;
        proxy_set_header Accept-Encoding gzip;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # 默认服务（如 code-server）
    location / {
        proxy_pass http://localhost:8080/;
        proxy_set_header Host $host;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection upgrade;
        proxy_set_header Accept-Encoding gzip;
    }
}
```

#### 关键配置要点

1. **location 优先级**：
   - `^~` 前缀匹配优先级最高
   - 静态文件配置必须在动态代理之前

2. **代理地址**：
   - 使用 `127.0.0.1` 而不是 `localhost`
   - 确保后端服务绑定正确的地址

3. **缓存控制**：
   - 静态文件禁用缓存避免更新问题
   - API 请求禁用 proxy_buffering

4. **Nginx 服务管理**：
   - ⚠️ **永远不要重启 nginx**：`sudo systemctl restart nginx`
   - ✅ **始终使用 reload**：`sudo systemctl reload nginx`
   - reload 是热重载，不会中断现有连接
   - restart 会断开所有连接，影响用户体验

### 3. 服务绑定和端口管理

#### 后端服务配置

```python
# FastAPI 配置
app = FastAPI()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)  # 绑定所有接口
```

#### 前端开发服务器

```typescript
// vite.config.ts
server: {
  port: 5173,
  host: '0.0.0.0',  // 允许外部访问
  allowedHosts: ['your-domain.cloudfront.net'],
}
```

#### 端口检查命令

```bash
# 检查端口绑定
ss -tlnp | grep :5173
ss -tlnp | grep :8000

# 检查进程
lsof -ti:5173,5174
kill $(lsof -ti:5173,5174)  # 清理端口
```

### 4. 常见问题排查

#### 问题 1：Blocked request host not allowed

**错误**：`This host is not allowed`

**解决**：在 `vite.config.ts` 中添加 `allowedHosts`

```typescript
server: {
  allowedHosts: ['your-domain.cloudfront.net'],
}
```

#### 问题 2：API 请求 404

**错误**：`GET /api/info 404 (Not Found)`

**原因**：nginx 没有配置 API 代理

**解决**：添加 API location 配置

#### 问题 3：静态资源 404

**错误**：`GET /@vite/client 404`

**原因**：访问的是开发服务器而不是静态文件

**解决**：
1. 构建生产版本
2. 配置 nginx 静态文件服务
3. 确保 location 优先级正确

#### 问题 4：SSE 流式响应问题

**错误**：Server-Sent Events 连接失败

**解决**：nginx 配置添加 SSE 支持

```nginx
location /api/ {
    proxy_buffering off;
    proxy_cache off;
    proxy_set_header Connection '';
    proxy_http_version 1.1;
    chunked_transfer_encoding off;
}
```

### 5. 部署流程最佳实践

#### 自动化部署脚本

```bash
#!/bin/bash
# deploy.sh

set -e

echo "Building frontend..."
cd frontend
VITE_BASE_URL=/proxy/5173/ npm run build

echo "Deploying static files..."
sudo rm -rf /var/www/html/proxy/5173/*
sudo cp -r dist/* /var/www/html/proxy/5173/

echo "Reloading nginx..."
sudo nginx -t
sudo systemctl reload nginx

echo "Starting backend..."
cd ../backend
pkill -f "python main.py" || true
python main.py > logs/backend-$(date +%Y%m%d-%H%M%S).log 2>&1 &

echo "Deployment complete!"
echo "Frontend: https://your-domain.cloudfront.net/proxy/5173/"
echo "API: https://your-domain.cloudfront.net/api/health"
```

#### 健康检查

```bash
# 检查服务状态
curl -s http://localhost/proxy/5173/ | head -5
curl -s http://localhost/api/health
curl -s https://your-domain.cloudfront.net/api/health
```

### 6. 开发 vs 生产环境

| 环境 | 前端访问 | 后端访问 | 配置要点 |
|------|----------|----------|----------|
| **开发** | `http://localhost:5173` | `http://localhost:8000` | Vite dev server + 本地代理 |
| **生产** | `https://domain.com/proxy/5173/` | `https://domain.com/api/` | 静态文件 + nginx 代理 |

#### 环境切换

```bash
# 开发环境
cd frontend && npm run dev
cd backend && python main.py

# 生产环境
cd frontend && VITE_BASE_URL=/proxy/5173/ npm run build
sudo cp -r dist/* /var/www/html/proxy/5173/
sudo systemctl reload nginx
```

## 总结

### 关键经验

1. **开发服务器不适合生产代理**：必须使用构建后的静态文件
2. **nginx 配置顺序很重要**：静态文件配置要在动态代理之前
3. **地址绑定要正确**：使用 `127.0.0.1` 而不是 `localhost`
4. **缓存控制很关键**：禁用缓存避免更新问题
5. **TypeScript 配置要适配**：构建时放宽某些限制

### 最佳实践

1. **分离开发和生产配置**：使用环境变量控制 base URL
2. **完整的健康检查**：验证静态文件、API、代理都正常
3. **自动化部署脚本**：减少手动操作错误
4. **详细的错误日志**：便于问题排查
5. **渐进式验证**：本地 → nginx → CloudFront 逐步验证

这套配置方案已在实际项目中验证，可以作为 CloudFront + EC2 + Nginx + Vite 部署的标准模板。
