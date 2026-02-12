# syntax=docker/dockerfile:1

############################
# 1) Build frontend
############################
FROM node:20-slim AS frontend-builder
WORKDIR /app/frontend

COPY frontend/package*.json ./
RUN npm install

COPY frontend/ ./
# 兼容：有的前端输出 build，有的输出 dist
RUN npm run build && \
    if [ -d dist ]; then echo "frontend: dist ok"; \
    elif [ -d build ]; then mv build dist; echo "frontend: build -> dist"; \
    else echo "frontend build output not found (dist/build)"; exit 1; fi


############################
# 2) Runtime
############################
FROM python:3.11-slim AS runtime
WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    DISPLAY=:99

# 关键：安装 Chromium + Xvfb + bash/procps（entrypoint 里用到 bash/pkill）
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    procps \
    curl \
    ca-certificates \
    xvfb \
    fonts-noto-cjk \
    fonts-noto-color-emoji \
    chromium \
 && rm -rf /var/lib/apt/lists/*

# 兼容各种“自动找浏览器路径”的代码：给常见名字做软链接
RUN ln -sf /usr/bin/chromium /usr/bin/google-chrome || true && \
    ln -sf /usr/bin/chromium /usr/bin/google-chrome-stable || true && \
    ln -sf /usr/bin/chromium /usr/bin/chromium-browser || true

# 常见环境变量（有些库会读这些）
ENV CHROME_BIN=/usr/bin/chromium \
    CHROMIUM_BIN=/usr/bin/chromium \
    BROWSER_BIN=/usr/bin/chromium \
    BROWSER_PATH=/usr/bin/chromium \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium \
    CHROME_FLAGS="--no-sandbox --disable-dev-shm-usage"

COPY requirements.txt /app/requirements.txt
RUN pip install -r /app/requirements.txt

COPY . /app
COPY --from=frontend-builder /app/frontend/dist /app/frontend/dist

RUN chmod +x /app/entrypoint.sh

# Zeabur 固定 8080，你的 entrypoint 会用 $PORT（没有就默认 8080）
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
  CMD curl -fsS http://127.0.0.1:${PORT:-8080}/admin/health || exit 1

ENTRYPOINT ["/app/entrypoint.sh"]
