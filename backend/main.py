import asyncio
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers.chat import router as chat_router, set_services
from mcp_client_manager import MCPClientManager
from agent_service import AgentService

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Global instances
mcp_manager: MCPClientManager = None
agent_service: AgentService = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager"""
    global mcp_manager, agent_service
    
    # Startup
    logger.info("Initializing MCP Client Manager...")
    mcp_manager = MCPClientManager()
    await mcp_manager.initialize_all_servers()
    
    logger.info("Initializing Agent Service...")
    agent_service = AgentService()
    await agent_service.initialize_agent(mcp_manager)
    
    # Set services in router
    set_services(agent_service, mcp_manager)
    
    logger.info("Application startup complete")
    
    yield
    
    # Shutdown
    logger.info("Application shutdown")

app = FastAPI(
    title="MCP Chatbot API",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://localhost:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(chat_router)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
