#!/bin/bash

# 创建 logs 目录
mkdir -p logs

# 生成时间戳
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# 后台启动 uvicorn 并记录 PID
nohup uvicorn main:app --host 0.0.0.0 --port 8000 > logs/backend-${TIMESTAMP}.log 2>&1 &
PID=$!

# 保存 PID
echo $PID > logs/backend.pid

echo "Backend started with PID: $PID"
echo "Log file: logs/backend-${TIMESTAMP}.log"
echo "To stop: kill \$(cat logs/backend.pid)"
