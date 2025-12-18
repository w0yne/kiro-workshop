import asyncio
import logging
from typing import Dict, List, Any
from mcp.client.streamable_http import streamablehttp_client
from strands.tools.mcp import MCPClient

logger = logging.getLogger(__name__)

class MCPClientManager:
    def __init__(self):
        self.clients: Dict[str, MCPClient] = {}
        self.server_configs = {
            "aws-knowledge": {
                "type": "streamablehttp",
                "url": "https://knowledge-mcp.global.api.aws"
            }
        }
    
    async def initialize_all_servers(self):
        """初始化所有配置的 MCP servers"""
        for server_name, config in self.server_configs.items():
            try:
                await self.connect_server(server_name, config)
                logger.info(f"Successfully connected to {server_name} MCP server")
            except Exception as e:
                logger.error(f"Failed to connect to {server_name} MCP server: {e}")
                # 继续初始化其他 servers，不中断启动
    
    async def connect_server(self, name: str, config: Dict[str, Any]):
        """连接到 MCP server"""
        if config["type"] == "streamablehttp":
            await self._connect_http_server(name, config)
        else:
            raise ValueError(f"Unsupported server type: {config['type']}")
    
    async def _connect_http_server(self, name: str, config: Dict[str, Any]):
        """连接到 HTTP MCP server"""
        url = config["url"]
        
        # 创建 MCPClient with Streamable HTTP transport
        mcp_client = MCPClient(lambda: streamablehttp_client(url))
        
        # 存储 client
        self.clients[name] = mcp_client
        logger.info(f"Created {name} MCP client with Streamable HTTP transport")
    
    def get_mcp_clients(self) -> List[MCPClient]:
        """获取所有 MCP clients 用于 Agent"""
        return list(self.clients.values())
    
    def get_server_status(self) -> Dict[str, bool]:
        """获取 MCP servers 连接状态"""
        status = {}
        for server_name in self.server_configs.keys():
            # 简单检查是否有对应的 client
            status[server_name] = server_name in self.clients
        return status
