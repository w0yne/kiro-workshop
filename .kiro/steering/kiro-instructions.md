---
inclusion: always
---

# Kiro 工作指南

本文档定义了 Kiro 在此 workspace 中的工作规范和最佳实践。

## 沟通语言

- **主要语言**: 中文
- **专业术语**: 使用英文（软件开发相关的技术术语、工具名称、命令等）
- **响应语言**: 如果用户用英文提问，则用英文回答

## 代码验证

- **避免内联测试**: 不要生成冗长的内联代码来验证或测试代码
- **临时测试文件**: 如果确实需要测试，创建临时测试文件，使用后删除

## 命令执行规范

### 避免阻塞命令

不要直接执行会阻塞命令行的命令，例如：
- 开发服务器: `npm run dev`, `uvicorn main:app`
- 构建监听: `webpack --watch`
- 交互式工具: `vim`, `nano`

### 后台服务管理

如果需要启动服务进行测试，使用后台运行方式：
- 使用 `nohup` 或 `&` 后台运行
- 记录 PID 以便后续清理
- 将日志重定向到文件

**日志保存位置**:
- Frontend: `frontend/logs/{datetime}.log`
- Backend: `backend/logs/{datetime}.log`

### 示例

```bash
# ❌ 错误 - 会阻塞命令行
npm run dev

# ✅ 正确 - 后台运行并记录 PID
nohup npm run dev > frontend/logs/dev-$(date +%Y%m%d-%H%M%S).log 2>&1 & echo $! > frontend/logs/dev.pid

# 停止服务
kill $(cat frontend/logs/dev.pid)
```