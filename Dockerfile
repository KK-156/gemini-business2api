# syntax=docker/dockerfile:1

############################
# 1) Frontend Builder
############################
FROM node:20-slim AS frontend-builder

WORKDIR /app/frontend

# 先只拷贝依赖清单，提高缓存命中
COPY frontend/package*.json ./

# 有 lock 用 ci，没有就 install（更兼容）
RUN if [ -f package-lock.json ]; then npm ci; else npm install; fi

# 再拷贝前端源码
COPY frontend/ ./

# 构建前端
RUN npm run build

# 收集前端产物：你的项目日志显示输出到 ../static（也就是 /app/static）
WORKDIR /app
RUN set -eux; \
    mkdir -p /out/static; \
    if [ -d "/app/static" ]; then \
      echo "✅ frontend output: /app/static"; \
      cp -a /app/static/. /out/static/; \
    elif [ -d "/app/frontend/dist" ]; then \
      echo "✅ frontend output: /app/frontend/dist"; \
      cp -a /app/frontend/dist/. /out/static/; \
    elif [ -d "/app/frontend/build" ]; then \
      echo "✅ frontend output: /app/frontend/build"; \
      cp -a /app/frontend/build/. /out/static/; \
    else \
      echo "❌ frontend build output not found (static/dist/build)"; \
      ls -la /app; ls -la /app/frontend; \
      exit 1; \
    fi


############################
# 2) Runtime
############################
FROM python:3.11-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# 装 chromium + xvfb（无头/有头都兼容）
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ca-certificates curl bash procps \
      xvfb \
      chromium chromium-driver \
      fonts-noto-cjk fonts-liberation \
    ; \
    rm -rf /var/lib/apt/lists/*; \
    # 兼容不同库寻找浏览器的路径
    ln -sf /usr/bin/chromium /usr/bin/google-chrome; \
    ln -sf /usr/bin/chromium /usr/bin/chromium-browser

# 给各种自动化库“指路”（多放几个更稳）
ENV CHROME_BIN=/usr/bin/chromium \
    CHROMIUM_PATH=/usr/bin/chromium \
    BROWSER_EXECUTABLE_PATH=/usr/bin/chromium \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium \
    DISPLAY=:99

WORKDIR /app

# 先装 python 依赖
COPY requirements.txt ./
RUN pip install -r requirements.txt

# 再拷贝后端代码
COPY . .

# 拷贝前端静态资源到后端 static（你的旧 Dockerfile 就是这个逻辑）
RUN mkdir -p /app/static
COPY --from=frontend-builder /out/static/ /app/static/

# entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh

EXPOSE 8080
ENTRYPOINT ["/entrypoint.sh"]
