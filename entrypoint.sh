#!/bin/bash
set -e

# Zeabur 会注入 PORT，没注入就用 8080
export HOST="${HOST:-0.0.0.0}"
export PORT="${PORT:-8080}"

# 给浏览器路径兜底（避免自动刷新时报“无法找到浏览器可执行文件路径”）
export CHROME_PATH="${CHROME_PATH:-/usr/bin/chromium}"
export CHROMIUM_PATH="${CHROMIUM_PATH:-/usr/bin/chromium}"
export BROWSER_PATH="${BROWSER_PATH:-/usr/bin/chromium}"

# 启动 Xvfb（有些“非无头/伪有头”方案需要）
Xvfb :99 -screen 0 1280x800x24 -ac &
sleep 1
export DISPLAY=:99

# 优先用 uvicorn 按 PORT 启动（能彻底解决写死 7860 的问题）
# 如果 main.py 里没有 app，再回退 python main.py
python - <<'PY'
import importlib
m = importlib.import_module("main")
raise SystemExit(0 if hasattr(m, "app") else 1)
PY

if [ $? -eq 0 ]; then
  exec uvicorn main:app --host "$HOST" --port "$PORT"
else
  exec python -u main.py
fi
