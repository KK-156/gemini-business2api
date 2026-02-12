#!/bin/bash
set -e

# Zeabur 常见：WEB_PORT/PORT 之一会存在
export PORT="${PORT:-${WEB_PORT:-8080}}"
export HOST="${HOST:-0.0.0.0}"

# 启动 Xvfb 在后台
Xvfb :99 -screen 0 1280x800x24 -ac &

# 等待 Xvfb 启动
sleep 1

# 设置 DISPLAY 环境变量
export DISPLAY=:99

# 启动 Python 应用
exec python -u main.py
