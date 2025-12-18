# MCP Server Development Guide

本指南提供了构建 MCP (Model Context Protocol) server 的架构模式和最佳实践，特别适用于对接 RESTful API 的场景。基于实际生产项目的经验总结。

## 核心架构

### 三层架构模式

MCP server 采用清晰的三层架构，职责分离：

```
server.py (MCP Layer)
    ↓ 调用
tool_handlers.py (Business Logic Layer)
    ↓ 调用
http_client.py (Data Access Layer)
```

**1. MCP Layer (server.py)**
- 使用 FastMCP framework 定义 MCP server
- 通过 `@mcp.tool()` decorator 注册 tools
- 提供详细的参数文档和类型注解
- 作为 thin wrapper，将请求转发给 handler 层

**2. Business Logic Layer (tool_handlers.py)**
- 实现核心业务逻辑
- 处理参数验证和转换
- 协调多个数据源（如需要）
- 返回标准化的响应格式

**3. Data Access Layer (http_client.py)**
- 处理外部 API 通信
- 构建请求参数
- 统一错误处理
- 管理连接和超时

## 关键实现细节

### 1. FastMCP Server 初始化

```python
from mcp.server.fastmcp import FastMCP

# 使用唯一的 server name 初始化
mcp = FastMCP("your-server-name")
```

### 2. Tool 定义模式

每个 tool 遵循统一的定义模式：

```python
@mcp.tool(
    description=(
        "详细的 tool 描述，包括：\n"
        "- 功能说明\n"
        "- 重要的使用注意事项\n"
        "- 查询语法要求\n"
        "- 常用字段说明\n"
        "- 具体的查询示例"
    )
)
def tool_name(
    param1: Annotated[
        Optional[Type],
        Field(
            default=default_value,
            description="参数详细说明，包括格式要求和示例"
        )
    ] = default_value,
    # ... 更多参数
) -> ReturnType:
    """
    Tool 的 docstring，包含：
    - 功能概述
    - Args 详细说明
    - Returns 说明
    - 使用示例
    """
    return handler_function(param1, ...)
```

### 3. 参数类型注解最佳实践

使用 `typing_extensions.Annotated` 和 `pydantic.Field` 提供丰富的参数元数据：

```python
from typing import Optional
from typing_extensions import Annotated
from pydantic import Field

# 字符串参数示例
search: Annotated[
    Optional[str],
    Field(
        default=None,
        description="详细的参数说明，包括格式要求和具体示例"
    )
] = None

# 整数参数示例
limit: Annotated[
    Optional[int],
    Field(
        default=1,
        description="返回结果数量 (default: 1, max: 1000)"
    )
] = 1
```

### 4. Handler 函数模式

Handler 函数保持简洁，专注于业务逻辑：

```python
def handler_function(
    param1: Optional[Type1] = default1,
    param2: Optional[Type2] = default2,
    # ... 更多参数
) -> Dict[str, Any]:
    """
    Handler 的详细文档
    
    Args:
        param1: 参数说明和示例
        param2: 参数说明和示例
        
    Returns:
        返回值说明
        
    Example:
        >>> result = handler_function(param1="value")
    """
    # 1. 构建请求参数
    params = build_query_params(param1, param2, ...)
    
    # 2. 调用数据访问层
    return make_api_request(endpoint, params)
```

### 5. HTTP Client 实现模式

#### 参数构建函数

```python
def build_query_params(
    param1: Optional[Type1] = None,
    param2: Optional[Type2] = None,
    # ... 更多参数
) -> Dict[str, Any]:
    """构建查询参数字典，过滤掉 None 和空字符串"""
    params = {}
    
    # 只包含有值的参数
    if param1 is not None and param1 != "":
        params["param1"] = param1
    
    # 包含 0 等有效值
    if param2 is not None:
        params["param2"] = param2
    
    return params
```

#### API 请求函数

```python
import httpx
from typing import Dict, Any

BASE_URL = "https://api.example.com"

def make_api_request(endpoint: str, params: Dict[str, Any]) -> Dict[str, Any]:
    """
    执行 HTTP 请求并处理错误
    
    返回格式：
    - 成功: 原始 JSON 响应
    - 失败: {"error": {"code": "...", "message": "..."}}
    """
    url = f"{BASE_URL}{endpoint}"
    
    try:
        response = httpx.get(url, params=params, timeout=30.0)
        
        # 处理特定的 HTTP 状态码
        if response.status_code == 400:
            try:
                return response.json()
            except Exception:
                return {
                    "error": {
                        "code": "BAD_REQUEST",
                        "message": "Invalid request"
                    }
                }
        
        elif response.status_code == 404:
            try:
                return response.json()
            except Exception:
                return {
                    "error": {
                        "code": "NOT_FOUND",
                        "message": "Resource not found"
                    }
                }
        
        elif response.status_code == 429:
            return {
                "error": {
                    "code": "RATE_LIMIT_EXCEEDED",
                    "message": "Rate limit exceeded"
                }
            }
        
        elif response.status_code >= 400:
            try:
                return response.json()
            except Exception:
                return {
                    "error": {
                        "code": f"HTTP_{response.status_code}",
                        "message": f"HTTP error {response.status_code}"
                    }
                }
        
        # 成功响应
        return response.json()
    
    except httpx.ConnectError as e:
        return {
            "error": {
                "code": "NETWORK_ERROR",
                "message": f"Connection failed: {str(e)}"
            }
        }
    
    except httpx.TimeoutException as e:
        return {
            "error": {
                "code": "TIMEOUT_ERROR",
                "message": f"Request timed out: {str(e)}"
            }
        }
    
    except Exception as e:
        return {
            "error": {
                "code": "UNKNOWN_ERROR",
                "message": f"Unexpected error: {str(e)}"
            }
        }
```

### 6. Server Entry Point

```python
def main() -> None:
    """
    MCP server 的主入口点
    
    使用 stdio transport 运行 server，处理：
    - 正常的 server 运行
    - Ctrl+C 优雅关闭
    - 异常错误处理
    """
    try:
        # 使用 stdio transport 运行 server
        mcp.run(transport="stdio")
    except KeyboardInterrupt:
        # 用户主动关闭，无需错误消息
        pass
    except Exception as e:
        import sys
        print(f"Error running MCP server: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
```

## 项目配置

### pyproject.toml 配置

```toml
[project]
name = "your-mcp-server"
version = "0.1.0"
description = "MCP server description"
readme = "README.md"
requires-python = ">=3.10"
dependencies = [
    "mcp>=0.1.0",
    "httpx>=0.27.0",  # 用于 HTTP 请求
]

[project.scripts]
# 定义命令行入口点
your-mcp-server = "your_package:main"

[build-system]
requires = ["setuptools>=61.0"]
build-backend = "setuptools.build_meta"
```

## 目录结构

```
your-mcp-server/
├── src/
│   └── your_package/
│       ├── __init__.py          # Package entry point
│       ├── __main__.py          # 支持 python -m your_package
│       ├── server.py            # MCP server 和 tool 定义
│       ├── tool_handlers.py     # Business logic handlers
│       └── http_client.py       # HTTP client 实现
├── pyproject.toml               # 项目配置
└── README.md                    # 文档
```

## 最佳实践

### 1. 文档优先

- Tool description 要详细，包含使用场景和示例
- 每个参数都要有清晰的说明和示例
- 在 description 中强调重要的使用注意事项
- 提供具体的查询示例，而不是抽象的说明

### 2. 类型安全

- 所有函数参数和返回值都要有类型注解
- 使用 `Optional[Type]` 表示可选参数
- 使用 `Annotated` 和 `Field` 提供参数元数据
- 保持类型注解的一致性

### 3. 错误处理

- 统一的错误响应格式：`{"error": {"code": "...", "message": "..."}}`
- 区分不同类型的错误（网络错误、API 错误、参数错误等）
- 提供有意义的错误消息
- 在 HTTP client 层集中处理所有错误

### 4. 职责分离

- Server 层只负责 MCP protocol 和参数文档
- Handler 层负责业务逻辑
- HTTP client 层负责外部通信
- 每层保持独立，便于测试和维护

### 5. 参数处理

- 使用 `Optional` 类型表示可选参数
- 提供合理的默认值
- 在构建请求时过滤掉 None 和空字符串
- 保留有效的 0 值（如 skip=0）



## 常见模式

### 多个相似 Tools

当有多个相似的 tools 时：

1. 在 handler 层实现通用逻辑
2. 在 server 层为每个 tool 提供特定的文档
3. 使用相同的参数结构保持一致性
4. 在 description 中突出每个 tool 的特定用途

### 分页支持

```python
limit: Annotated[
    Optional[int],
    Field(
        default=1,
        description="Number of results to return (default: 1, max: 1000)"
    )
] = 1,
skip: Annotated[
    Optional[int],
    Field(
        default=0,
        description="Number of results to skip for pagination (default: 0)"
    )
] = 0,
```

### 聚合查询

```python
count: Annotated[
    Optional[str],
    Field(
        default=None,
        description="Field to count by (returns aggregated counts instead of records). "
        "Example: 'field_name.exact'"
    )
] = None,
```

### API Key 支持

```python
api_key: Annotated[
    Optional[str],
    Field(
        default=None,
        description="Optional API key for higher rate limits"
    )
] = None,
```

## 运行和部署

### 安装

```bash
# 从源码安装
pip install -e .
```

### 运行

```bash
# 使用命令行入口
your-mcp-server

# 使用 Python module
python -m your_package
```

## 关键文件说明

### __init__.py - Package Entry Point

**职责**：
- 提供 package 级别的文档说明
- 导出 main 函数作为入口点
- 定义版本号和公开接口

**关键要点**：
- 使用详细的 docstring 说明 server 的功能和使用方法
- 通过 `__all__` 控制导出内容
- 保持简洁，只负责导出和文档

### __main__.py - Module Execution Entry

**职责**：
- 支持 `python -m your_package` 方式运行
- 作为模块执行的入口点

**关键要点**：
- 只需要导入并调用 main 函数
- 保持极简，不包含任何业务逻辑

## RESTful API 对接的特定模式

### 查询参数构建策略

**常见参数类型**：
- **搜索/过滤**：search, filter, q
- **聚合/统计**：count, group_by
- **分页**：limit, offset, skip, page, per_page
- **排序**：sort, order
- **认证**：api_key, token

**关键原则**：
1. **字符串参数**：过滤掉 None 和空字符串
2. **数值参数**：保留 0 值（0 是有效的分页参数）
3. **使用循环**：避免重复的 if 语句
4. **根据 API 需求**：只包含目标 API 实际支持的参数

### HTTP 方法支持

**设计要点**：
- 支持 GET, POST, PUT, DELETE 等方法
- GET 请求使用 query parameters
- POST/PUT 请求使用 JSON body
- 为不支持的方法返回明确的错误
- 保持错误处理逻辑的一致性

### 认证模式

**三种常见方式**：

1. **Query Parameter 认证**
   - 将 API key 作为查询参数
   - 适合简单的公开 API

2. **Header 认证**
   - Bearer Token: `Authorization: Bearer {token}`
   - API Key Header: `X-API-Key: {key}`
   - 更安全，不会出现在 URL 中

3. **Basic Auth**
   - 使用 username 和 password
   - httpx 提供原生支持

**选择建议**：根据目标 API 的文档要求选择合适的认证方式

## 实际应用场景

### 场景 1：简单的查询 API

**特点**：
- 单一搜索参数（如 q, keyword）
- 基本的分页支持（limit, offset）
- 简单的 JSON 响应

**实现要点**：
- 参数构建函数只需处理 3-5 个参数
- Handler 层直接调用 API，无需复杂转换
- Tool description 重点说明搜索关键词的使用

### 场景 2：复杂的查询语法

**特点**：
- 支持结构化查询语法（如 Lucene, MongoDB query）
- 需要 field:value 格式
- 支持逻辑操作符（AND, OR, NOT）

**实现要点**：
- 在 tool description 中**强调查询语法要求**
- 提供多个具体的查询示例
- 在参数 Field description 中重复说明格式要求
- 考虑在 handler 层添加基本的语法验证

### 场景 3：多个相关 Endpoints

**特点**：
- 同一 API 有多个相关的 endpoints
- 参数结构相似但用途不同
- 需要为每个 endpoint 创建独立的 tool

**实现要点**：
- 在 handler 层为每个 endpoint 创建独立函数
- 可以共用 `build_query_params` 函数
- 在 server 层为每个 endpoint 创建独立的 tool
- Tool description 中明确说明每个 tool 的特定用途
- 保持参数结构的一致性，便于用户理解

## 总结

本指南涵盖了构建 RESTful API MCP server 的完整实现：

1. **三层架构**：清晰的职责分离
2. **完整的代码实现**：包括 `__init__.py`、`__main__.py`、server、handler、http_client
3. **错误处理**：全面的错误处理和统一的错误格式
4. **参数处理**：正确处理不同类型的参数
5. **文档规范**：多层次的文档策略
6. **实际应用示例**：不同场景的具体实现

遵循这些模式可以构建健壮、可维护的 MCP server。
