#!/bin/sh
set -e

export DISPLAY=:99

# 启动虚拟屏幕（无头浏览器需要）
Xvfb :99 -screen 0 1280x720x24 -ac +extension GLX +render -noreset &
sleep 0.5

# 启动后端（项目默认就是 python main.py）
exec python main.py
