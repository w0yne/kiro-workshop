import json
import logging
from datetime import datetime
from typing import Dict, Any
from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
from models import ChatRequest, InfoResponse, HealthResponse, ModelInfo, ToolInfo
from agent_service import AgentService
from mcp_client_manager import MCPClientManager

logger = logging.getLogger(__name__)
router = APIRouter()

# Global instances (will be initialized in main.py)
agent_service: AgentService = None
mcp_manager: MCPClientManager = None

def set_services(agent: AgentService, mcp: MCPClientManager):
    """Set global service instances"""
    global agent_service, mcp_manager
    agent_service = agent
    mcp_manager = mcp

@router.post("/api/chat")
async def chat(request: ChatRequest):
    """处理聊天请求，返回 SSE 流式响应"""
    if not agent_service:
        raise HTTPException(status_code=500, detail="Agent service not initialized")
    
    async def generate_sse():
        try:
            async for event in agent_service.process_message(request.messages, request.session_id):
                # 发送 SSE 事件
                event_data = json.dumps(event)
                yield f"data: {event_data}\n\n"
            
            # 发送完成标记
            yield "data: [DONE]\n\n"
            
        except Exception as e:
            logger.error(f"Chat error: {e}")
            error_event = {
                "type": "error",
                "data": str(e),
                "metadata": {"session_id": request.session_id}
            }
            yield f"data: {json.dumps(error_event)}\n\n"
    
    return StreamingResponse(
        generate_sse(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
        }
    )

@router.get("/api/info")
async def get_info() -> InfoResponse:
    """获取模型信息和可用工具列表"""
    if not mcp_manager:
        raise HTTPException(status_code=500, detail="MCP manager not initialized")
    
    # 模型信息
    model_info = ModelInfo(
        name="Claude Sonnet 4",
        model_id="us.anthropic.claude-sonnet-4-20250514-v1:0",
        region="us-east-1"
    )
    
    # MCP servers 信息
    mcp_servers = []
    server_status = mcp_manager.get_server_status()
    
    for server_name in mcp_manager.server_configs.keys():
        is_connected = server_status.get(server_name, False)
        # 根据 server 类型提供工具列表
        if server_name == "openfda" and is_connected:
            tools = ["search_drug_label", "get_drug_adverse_events", "count_adverse_events"]
        elif server_name == "aws-knowledge" and is_connected:
            tools = ["search_docs", "recommend", "fetch_doc"]
        else:
            tools = []
        
        mcp_servers.append(ToolInfo(
            server_name=server_name,
            is_connected=is_connected,
            tools=tools
        ))
    
    return InfoResponse(
        model=model_info,
        mcp_servers=mcp_servers
    )

@router.get("/api/health")
async def health_check() -> HealthResponse:
    """健康检查端点，返回服务状态和 MCP servers 连接状态"""
    if not mcp_manager:
        raise HTTPException(status_code=500, detail="MCP manager not initialized")
    
    # 检查 MCP servers 连接状态
    mcp_status = mcp_manager.get_server_status()
    
    return HealthResponse(
        status="ok",
        mcp_servers=mcp_status,
        timestamp=datetime.now()
    )
