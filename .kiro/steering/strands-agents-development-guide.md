# Strands Agents 开发指南

本指南基于实际项目经验，总结了使用 Strands Agents SDK 开发 AI 应用的最佳实践和常见问题解决方案。

## 核心架构

### Agent 基础配置

```python
from strands import Agent
from strands.models import BedrockModel

# 推荐的模型配置
model = BedrockModel(
    model_id="us.anthropic.claude-sonnet-4-20250514-v1:0",
    temperature=0.7,
    max_tokens=4096
)

agent = Agent(
    model=model,
    system_prompt="详细的系统提示...",
    tools=tools  # 工具列表
)
```

## MCP 集成最佳实践

### 1. 推荐方式：Managed Integration（实验性）

**✅ 推荐方式**（生产环境）：
```python
class AgentService:
    def __init__(self):
        self.model = BedrockModel(...)
        self.agent = None
    
    async def initialize_agent(self, mcp_clients):
        # 直接传递 MCPClient 实例给 Agent
        # Strands SDK 自动管理生命周期
        self.agent = Agent(
            model=self.model,
            system_prompt=self._get_system_prompt(),
            tools=mcp_clients  # 让 Strands 管理生命周期
        )
    
    async def process_message(self, message: str):
        # 直接调用，无需 context manager
        response = self.agent(message)
        return response
```

**优势**：
- 无需手动管理 context manager
- Strands SDK 自动处理 MCP client 的生命周期
- 代码更简洁，减少出错可能
- 更适合生产环境使用

### 2. Manual Context Management（不推荐）

**❌ 错误方式**：
```python
# 初始化时获取工具，运行时 context 已关闭
with mcp_client:
    tools = mcp_client.list_tools_sync()
    agent = Agent(tools=tools)

# 这里调用会失败：MCPClientInitializationError
response = agent("query")
```

**限制**：
- MCP client session 必须在整个 Agent 生命周期中保持活跃
- 无法在初始化时获取工具，运行时使用
- 每次调用都需要在 context 中创建 Agent

### 3. Transport 类型选择

**Stdio Transport**（本地 MCP server）：
```python
from mcp import stdio_client, StdioServerParameters
from strands.tools.mcp import MCPClient

mcp_client = MCPClient(lambda: stdio_client(
    StdioServerParameters(
        command="your-mcp-server",
        args=[],
        env=None
    )
))
```

**Streamable HTTP Transport**（远程 MCP server）：
```python
from mcp.client.streamable_http import streamablehttp_client
from strands.tools.mcp import MCPClient

mcp_client = MCPClient(lambda: streamablehttp_client(
    "https://your-mcp-server.com"
))
```

**常见错误**：
```python
# ❌ 错误 - 会导致 HTTP 405 错误
from mcp.client.sse import sse_client
mcp_client = MCPClient(lambda: sse_client(url))

# ✅ 正确 - 使用 streamablehttp_client
from mcp.client.streamable_http import streamablehttp_client
mcp_client = MCPClient(lambda: streamablehttp_client(url))
```

### 4. 多 MCP Server 集成

**推荐方式（Managed Integration）**：
```python
class AgentService:
    def __init__(self):
        self.model = BedrockModel(...)
        self.agent = None
    
    async def initialize_agent(self, mcp_clients):
        # 直接传递给 Agent，Strands 自动管理
        self.agent = Agent(
            model=self.model,
            tools=mcp_clients
        )
    
    async def process_message(self, message: str):
        # 直接调用，无需 context manager
        return self.agent(message)
```

## MCP 集成问题解决方案

### 常见问题

#### 1. MCPClientInitializationError

**错误信息**：
```
MCPClientInitializationError: the client session is not running
```

**原因**：Agent 在 MCP context manager 外部使用

**解决方案**：使用 Managed Integration 方式

#### 2. HTTP 405 错误

**错误信息**：
```
HTTPStatusError: Client error '405 Not Allowed'
```

**原因**：使用了错误的 transport 类型

**解决方案**：
- HTTP MCP server 使用 `streamablehttp_client`
- 本地 MCP server 使用 `stdio_client`

#### 3. 工具调用失败

**症状**：Agent 不调用 MCP 工具，使用通用知识回答

**解决方案**：
```python
# 1. 检查连接状态
try:
    with mcp_client:
        tools = mcp_client.list_tools_sync()
        logger.info(f"Loaded {len(tools)} tools")
except Exception as e:
    logger.error(f"MCP connection failed: {e}")

# 2. 优化 system prompt
system_prompt = """You are an AI assistant with access to external tools.

Available tools:
- Tool A: description and usage
- Tool B: description and usage

Guidelines:
- When users ask about X, use Tool A
- When users ask about Y, use Tool B
- Always use tools when relevant information is requested"""
```

### 最佳实践

#### 1. 使用 Managed Integration

```python
# 推荐方式
agent = Agent(
    model=model,
    tools=mcp_clients  # 直接传递 MCPClient 列表
)
```

#### 2. 优雅的错误处理

```python
async def initialize_agent(self, mcp_clients):
    try:
        self.agent = Agent(model=self.model, tools=mcp_clients)
        logger.info(f"Agent initialized with {len(mcp_clients)} MCP clients")
    except Exception as e:
        logger.error(f"Failed to initialize agent: {e}")
        # 降级：创建无工具的 Agent
        self.agent = Agent(model=self.model, tools=[])
```

## 项目结构建议

```
project/
├── agent_service.py          # Agent 服务层
├── mcp_client_manager.py     # MCP 客户端管理
├── models.py                 # Pydantic 模型
└── main.py                   # 应用入口
```

### Agent Service 模式

```python
class AgentService:
    def __init__(self):
        self.model = BedrockModel(...)
        self.agent = None
    
    async def initialize_agent(self, mcp_clients):
        """使用 Managed Integration 初始化 Agent"""
        self.agent = Agent(
            model=self.model,
            tools=mcp_clients
        )
    
    async def process_message(self, message: str):
        """处理用户消息"""
        try:
            return self.agent(message)
        except Exception as e:
            logger.error(f"Agent processing failed: {e}")
            # 降级处理
            fallback_agent = Agent(model=self.model, tools=[])
            return fallback_agent(message)
```

## 性能优化

### 1. 工具过滤

```python
# 只加载需要的工具
mcp_client = MCPClient(
    transport_func,
    tool_filters={"allowed": ["tool1", "tool2"]}
)
```

### 2. 错误处理

```python
# 优雅降级
try:
    agent = Agent(model=model, tools=mcp_clients)
    return agent(message)
except Exception as e:
    logger.warning(f"MCP failed: {e}")
    # 使用无工具 Agent 作为后备
    agent = Agent(model=model, tools=[])
    return agent(message)
```

## 部署注意事项

### 1. 环境变量

```bash
# AWS Bedrock
AWS_REGION=us-east-1
AWS_BEDROCK_MODEL_ID=us.anthropic.claude-sonnet-4-20250514-v1:0

# MCP Servers
MCP_SERVER_URL=https://your-mcp-server.com
```

### 2. 依赖管理

```txt
# requirements.txt
strands-agents>=0.1.0
mcp>=0.1.0
httpx>=0.27.0
```

### 3. 日志配置

```python
import logging

# 设置详细日志以便调试 MCP 连接
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)
```

## 调试技巧

### 1. 连接测试

```python
# 测试 MCP 连接
try:
    with mcp_client:
        tools = mcp_client.list_tools_sync()
        print(f"Available tools: {[t.name for t in tools]}")
except Exception as e:
    print(f"Connection failed: {e}")
```

### 2. 工具调用测试

```python
# 直接调用工具测试
with mcp_client:
    result = mcp_client.call_tool_sync(
        tool_use_id="test-123",
        name="tool_name",
        arguments={"param": "value"}
    )
    print(result)
```

## 总结

**关键原则**：
1. **使用 Managed Integration** - 让 Strands SDK 自动管理 MCP client 生命周期
2. **选择正确的 transport** - 根据 MCP server 类型选择合适的 transport
3. **优雅的错误处理** - 实现降级机制和详细日志
4. **及早测试连接** - 在开发过程中验证 MCP 连接

遵循这些实践可以避免大部分常见问题，构建稳定可靠的 Strands Agent 应用。
