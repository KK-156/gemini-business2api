#!/usr/bin/env bash
set -e

export PORT="${PORT:-8080}"
export HOST="${HOST:-0.0.0.0}"
export DISPLAY="${DISPLAY:-:99}"

# 启动虚拟显示（给自动化浏览器用）
Xvfb :99 -screen 0 1280x720x24 -ac +extension RANDR &
sleep 1

# ✅ 用 uvicorn 强制监听 Zeabur 的 PORT
exec python -m uvicorn main:app --host "$HOST" --port "$PORT"
