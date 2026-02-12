# Stage 1: 构建前端
FROM node:20-slim AS frontend-builder
WORKDIR /app/frontend

# 直接复制前端目录（牺牲一点缓存，换稳定不踩坑）
COPY frontend/ /app/frontend/

RUN npm install --no-audit --no-fund

# 构建并把输出统一整理到 /app/static
RUN npm run build && \
    if [ -d /app/static ]; then \
      echo "[frontend] build output already in /app/static"; \
    elif [ -d /app/frontend/static ]; then \
      mkdir -p /app/static && cp -r /app/frontend/static/* /app/static/; \
    elif [ -d /app/frontend/dist ]; then \
      mkdir -p /app/static && cp -r /app/frontend/dist/* /app/static/; \
    elif [ -d /app/frontend/build ]; then \
      mkdir -p /app/static && cp -r /app/frontend/build/* /app/static/; \
    else \
      echo "[frontend] ERROR: no build output found (static/dist/build not found)"; \
      ls -al /app/frontend; \
      exit 1; \
    fi


# Stage 2: 后端运行环境
FROM python:3.11-slim
WORKDIR /app

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# 安装浏览器/驱动 + xvfb（用于无头浏览器）
RUN apt-get update && apt-get install -y --no-install-recommends \
      chromium chromium-driver \
      xvfb \
      ca-certificates curl \
      fonts-liberation \
      tzdata \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt /app/requirements.txt
RUN pip install -r /app/requirements.txt

# 复制后端代码
COPY . /app

# 复制前端静态资源（统一从 /app/static 拷贝）
COPY --from=frontend-builder /app/static /app/static

# 入口脚本
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Zeabur 固定 8080，但项目本身用 PORT 环境变量决定监听端口
EXPOSE 8080
EXPOSE 7860

# 健康检查（不用 CMD-SHELL！Dockerfile 里没有这个写法）
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD sh -c 'curl -fsS "http://127.0.0.1:${PORT:-7860}/admin/health" || exit 1'

ENTRYPOINT ["/entrypoint.sh"]
