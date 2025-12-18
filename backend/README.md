# MCP Chatbot Backend

基于 Strands Agent SDK 构建的 AI 聊天后端服务，集成 AWS Knowledge MCP server。

## 快速开始

### 安装依赖

```bash
pip install -r requirements.txt
```

### 环境配置

复制并编辑环境变量：

```bash
cp .env.example .env
```

配置 AWS 凭证和其他必要参数。

### 启动服务

```bash
./start.sh
```

服务将在 http://localhost:8000 启动。

### 停止服务

```bash
./stop.sh
```

## API 端点

- `POST /api/chat` - 流式聊天接口
- `GET /api/info` - 获取模型和工具信息  
- `GET /api/health` - 健康检查

## 技术栈

- FastAPI 0.115+
- Strands Agent SDK
- MCP Python SDK
- AWS Bedrock (Claude Sonnet 4)
