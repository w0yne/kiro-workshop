from pydantic import BaseModel, Field
from typing import List, Dict, Optional, Literal, Any
from datetime import datetime

class Message(BaseModel):
    role: Literal['system', 'user', 'assistant']
    content: str

class ChatRequest(BaseModel):
    messages: List[Message]
    context: Optional[Dict[str, Any]] = None
    session_id: Optional[str] = None

class StreamEvent(BaseModel):
    type: Literal['content', 'status', 'tool', 'complete', 'error']
    data: str
    metadata: Optional[Dict[str, Any]] = None

class ModelInfo(BaseModel):
    name: str
    model_id: str
    region: str

class ToolInfo(BaseModel):
    server_name: str
    is_connected: bool
    tools: List[str]

class InfoResponse(BaseModel):
    model: ModelInfo
    mcp_servers: List[ToolInfo]

class HealthResponse(BaseModel):
    status: str
    mcp_servers: Dict[str, bool]
    timestamp: datetime
