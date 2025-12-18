# Implementation Plan

基于当前已有的 Backend 基础架构，实现完整的 MCP Chatbot 系统。

## 当前状态
- ✅ Backend 基础架构（FastAPI + Strands Agent + AWS Knowledge MCP）
- ✅ API 端点（/api/chat, /api/info, /api/health）
- ✅ SSE 流式响应实现

## 待实现功能

- [ ] 1. 实现 OpenFDA MCP Server
  - 创建 openfda-mcp-server 目录结构（src/openfda_mcp/）
  - 创建 pyproject.toml（配置项目元数据和依赖）
  - 实现 http_client.py
    - build_query_params 函数（处理 search, limit, skip, count, api_key）
    - make_openfda_request 函数（统一错误处理）
  - 实现 tool_handlers.py
    - search_drug_label_handler（调用 /drug/label.json）
    - get_drug_adverse_events_handler（调用 /drug/event.json）
    - count_adverse_events_handler（聚合查询）
  - 实现 server.py
    - 使用 FastMCP 定义 MCP server
    - 定义 search_drug_label tool（详细的 Lucene 语法说明）
    - 定义 get_drug_adverse_events tool（字段名差异说明）
    - 定义 count_adverse_events tool（聚合查询说明）
    - 实现 main() 入口函数
  - 创建 __init__.py 和 __main__.py
  - **验证**: MCP server 可以独立运行并响应工具调用
  - _Requirements: 3.1, 3.2_

- [ ] 2. 扩展后端 MCP Client Manager
  - 更新 backend/mcp_client_manager.py
    - 添加 OpenFDA server 配置（stdio transport）
    - 实现 _connect_stdio_server 方法
    - 支持混合 transport 类型（HTTP + stdio）
  - 更新 requirements.txt 添加 OpenFDA MCP server 依赖
  - 更新 .env.example 添加 OPENFDA_API_KEY 配置
  - 测试双 MCP Server 集成
    - 验证 Agent 可以调用两个 MCP server 的工具
    - 验证 /api/info 和 /api/health 端点返回正确信息
  - **验证**: Backend API 完整支持双 MCP server
  - _Requirements: 3.1, 3.2, 4.1, 4.2_

- [ ] 3. 初始化前端项目和配置
  - 创建 frontend/ 目录
  - 初始化 Vite + React + TypeScript 项目
  - 配置 Tailwind CSS 4.0（安装 @tailwindcss/vite 插件，配置 tailwind.config.ts）
  - 配置 TypeScript 路径别名（@/* → ./src/*）
  - 配置 Vite 代理（/api → http://localhost:8000）
  - 安装核心依赖（React 19.2, Zustand, react-markdown, remark-gfm, lucide-react, shadcn/ui）
  - 全局安装并初始化 shadcn/ui（shadcn init）
  - 添加基础组件（Button, Textarea）
  - 创建 src/lib/utils.ts（cn 函数）
  - 配置 src/index.css（Tailwind 4.0 语法，CSS 变量，主题）
  - **验证**: Frontend 项目可以启动并访问 Backend API
  - _Requirements: 1.1, 6.1_

- [ ] 4. 实现前端类型定义和状态管理
  - 创建 src/types/index.ts
    - 定义 Message 接口（id, role, content, timestamp, isStreaming, metadata）
    - 定义 StreamEvent 接口（type, data, metadata）
    - 定义 ChatRequest 接口（messages, context, session_id）
  - 创建 src/store/chatStore.ts
    - 定义 ChatStore 接口（messages, sessionId, isLoading）
    - 实现 addMessage action（自动生成 id 和 timestamp）
    - 实现 updateMessage action（用于更新流式消息）
    - 实现 clearMessages action
    - 配置 devtools middleware
  - **验证**: TypeScript 编译通过，状态管理正常工作
  - _Requirements: 1.2, 1.3_

- [ ] 5. 实现前端 API 客户端和 Hooks
  - 创建 src/api/client.ts
    - 实现 streamChat 函数
    - 处理 SSE 连接（fetch with ReadableStream）
    - 实现 buffer 处理逻辑（处理不完整的行）
    - 解析 SSE 事件（data: 前缀，[DONE] 标记）
    - 支持 AbortController 取消
  - 创建 src/hooks/useStreamingChat.ts
    - 管理 isStreaming 和 streamingContent 状态
    - 使用 useRef 累积内容（accumulatedRef）
    - 实现 startStream 和 cancelStream 方法
    - 处理 content/complete/error 事件
  - 创建 src/hooks/useAutoScroll.ts
    - 管理自动滚动逻辑
  - **验证**: API 客户端可以正确处理 SSE 流式响应
  - _Requirements: 1.2, 3.1, 3.2_

- [ ] 6. 实现前端基础 UI 组件
  - 创建 src/components/Sidebar.tsx
    - 显示模型信息（名称、Region）
    - 显示可用工具列表（按 MCP server 分组）
    - 使用 ✓/✗ 标记连接状态
    - 调用 GET /api/info 获取数据
  - 创建 src/components/EmptyState.tsx
    - 显示欢迎信息和使用提示
  - 创建 src/components/MessageItem.tsx
    - 实现用户消息和 AI 消息的不同样式
    - 支持 Markdown 渲染（react-markdown + remark-gfm）
    - 使用 React.memo 优化性能
  - **验证**: UI 组件渲染正确，样式美观
  - _Requirements: 6.1, 6.2, 6.3, 6.4_

- [ ] 7. 实现前端聊天窗口和输入组件
  - 创建 src/components/InputArea.tsx
    - 使用 Textarea 组件
    - 实现 Enter 发送 / Shift+Enter 换行
    - 显示发送和停止按钮
    - disabled 状态处理
  - 创建 src/components/ChatWindow.tsx
    - Flexbox 垂直布局（flex flex-col h-full）
    - 消息列表区域（flex-1 overflow-y-auto）
    - 实现自动滚动逻辑
    - 对 isStreaming 消息使用 streamingContent 替换内容
    - 集成 InputArea 和 EmptyState
  - **验证**: 聊天功能完整，用户体验良好
  - _Requirements: 1.1, 1.4, 1.5, 4.1, 4.2_

- [ ] 8. 实现主应用和完整集成
  - 创建 src/App.tsx
    - 实现两栏布局（Sidebar + ChatWindow）
    - 使用 useChatStore 获取状态
    - 使用 useStreamingChat 管理流式聊天
    - 实现 handleSend 和 handleCancel 函数
  - 创建 src/main.tsx（React 入口）
  - 完善样式和响应式设计
  - **验证**: 完整应用功能正常，可以与 Backend 正常交互
  - _Requirements: 1.1, 1.2, 3.1, 6.1, 6.5_

- [ ] 9. 创建项目文档
  - 创建根目录 README.md
    - 项目介绍（概述、核心特性、架构）
    - 技术栈列表（Frontend, Backend, MCP Servers）
    - 前置要求（Node.js 18+, Python 3.11+, AWS 凭证）
    - 安装步骤（Backend 和 Frontend 安装命令）
    - 环境变量配置（backend/.env.example 说明）
    - 运行说明（Backend 和 Frontend 启动命令）
    - 功能特性列表和常见问题
  - 更新 Backend README.md
  - 创建 OpenFDA MCP Server README.md
  - **验证**: 文档完整，用户可以根据文档成功运行项目
  - _Requirements: 所有_
