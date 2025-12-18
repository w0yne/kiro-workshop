import asyncio
import logging
from typing import List, Dict, Any, Optional, AsyncGenerator
from strands import Agent
from strands.models import BedrockModel
from mcp_client_manager import MCPClientManager
from models import Message

logger = logging.getLogger(__name__)

class AgentService:
    def __init__(self):
        self.model = BedrockModel(
            model_id="us.anthropic.claude-sonnet-4-20250514-v1:0",
            temperature=0.7,
            max_tokens=4096
        )
        self.agent: Optional[Agent] = None
        self.mcp_manager: Optional[MCPClientManager] = None
    
    async def initialize_agent(self, mcp_manager: MCPClientManager):
        """初始化 agent 使用实验性 Managed Integration"""
        self.mcp_manager = mcp_manager
        
        # 获取所有 MCP clients
        mcp_clients = mcp_manager.get_mcp_clients()
        
        # 使用实验性的 Managed Integration
        # 直接传递 MCPClient 实例给 Agent，让 Strands 管理生命周期
        self.agent = Agent(
            model=self.model,
            system_prompt=self._get_system_prompt(),
            tools=mcp_clients  # 直接传递 MCPClient 列表
        )
        
        logger.info(f"Agent initialized with {len(mcp_clients)} MCP clients using managed integration")
    
    def _get_system_prompt(self) -> str:
        """配置 system prompt"""
        return """You are a helpful AI assistant with access to external tools via MCP servers.

Available capabilities:
- AWS Knowledge tools: Search AWS documentation, get recommendations, fetch documentation
- OpenFDA tools: Search drug labels, get adverse events, count statistics for pharmaceutical information

Guidelines:
- When users ask about AWS services, documentation, or cloud computing, use the AWS Knowledge tools
- When users ask about drugs, medications, or pharmaceutical information, use the OpenFDA tools
- Always provide accurate, helpful information based on the tool results
- If a tool call fails, explain the issue and suggest alternatives

You can help users with:
1. AWS services and documentation
2. Drug information and labeling
3. Adverse event reports
4. Pharmaceutical statistics and trends"""
    
    async def process_message(
        self, 
        messages: List[Message], 
        session_id: Optional[str] = None
    ) -> AsyncGenerator[Dict[str, Any], None]:
        """处理用户消息并返回流式响应"""
        if not self.agent:
            raise RuntimeError("Agent not initialized")
        
        try:
            # 获取最后一条用户消息
            last_user_message = None
            for msg in reversed(messages):
                if msg.role == "user":
                    last_user_message = msg.content
                    break
            
            if not last_user_message:
                yield {
                    "type": "error",
                    "data": "No user message found",
                    "metadata": {"session_id": session_id}
                }
                return
            
            # 使用 Strands Agent 的真正流式 API
            async for event in self.agent.stream_async(last_user_message):
                # 处理文本生成事件
                if "data" in event:
                    yield {
                        "type": "content",
                        "data": event["data"],
                        "metadata": {"session_id": session_id}
                    }
                
                # 处理工具使用事件
                elif "current_tool_use" in event:
                    tool_info = event["current_tool_use"]
                    if tool_info.get("name"):
                        yield {
                            "type": "tool",
                            "data": f"Using tool: {tool_info['name']}",
                            "metadata": {
                                "session_id": session_id,
                                "tool_name": tool_info["name"],
                                "tool_use_id": tool_info.get("toolUseId")
                            }
                        }
                
                # 处理状态事件
                elif event.get("init_event_loop"):
                    yield {
                        "type": "status",
                        "data": "Initializing...",
                        "metadata": {"session_id": session_id}
                    }
                
                elif event.get("start_event_loop"):
                    yield {
                        "type": "status", 
                        "data": "Processing...",
                        "metadata": {"session_id": session_id}
                    }
            
            # 流式循环结束后，发送完成事件
            yield {
                "type": "complete",
                "data": "",
                "metadata": {"session_id": session_id}
            }
            
        except Exception as e:
            logger.error(f"Error processing message: {e}")
            yield {
                "type": "error",
                "data": f"Error processing your request: {str(e)}",
                "metadata": {"session_id": session_id}
            }
