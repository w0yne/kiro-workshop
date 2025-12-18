#!/bin/bash

if [ -f logs/backend.pid ]; then
    PID=$(cat logs/backend.pid)
    if kill -0 $PID 2>/dev/null; then
        kill $PID
        echo "Backend stopped (PID: $PID)"
        rm logs/backend.pid
    else
        echo "Backend not running"
        rm logs/backend.pid
    fi
else
    echo "No PID file found"
fi
