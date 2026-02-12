# syntax=docker/dockerfile:1

############################
# 1) Build Frontend
############################
FROM node:20-slim AS frontend-builder

WORKDIR /app

# 先只拷贝 lock 文件，提升缓存命中率（兼容 npm / pnpm / yarn）
COPY frontend/package.json frontend/package-lock.json* frontend/pnpm-lock.yaml* frontend/yarn.lock* ./frontend/

RUN cd frontend && \
    if [ -f pnpm-lock.yaml ]; then corepack enable && pnpm i --frozen-lockfile; \
    elif [ -f yarn.lock ]; then corepack enable && yarn install --frozen-lockfile; \
    elif [ -f package-lock.json ]; then npm ci; \
    else npm install; fi

COPY frontend/ ./frontend/

# 构建并强制要求产物目录存在（避免后面 COPY 时报 dist not found）
RUN cd frontend && \
    if [ -f pnpm-lock.yaml ]; then pnpm run build; \
    elif [ -f yarn.lock ]; then yarn build; \
    else npm run build; fi && \
    test -d dist


############################
# 2) Runtime (Python + Chromium)
############################
FROM python:3.11-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive

WORKDIR /app

# 关键：安装 Chromium + Driver + 依赖（更兼容，适合 Zeabur / Debian 系）
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl tzdata \
      xvfb xauth \
      chromium chromium-driver \
      fonts-liberation \
      libasound2 libatk-bridge2.0-0 libatk1.0-0 \
      libcups2 libdbus-1-3 libdrm2 libgbm1 libglib2.0-0 \
      libnss3 libnspr4 \
      libx11-6 libx11-xcb1 libxcb1 \
      libxcomposite1 libxdamage1 libxext6 libxfixes3 \
      libxrandr2 libxrender1 libxshmfence1 libxtst6 \
      libgtk-3-0 libpango-1.0-0 libpangocairo-1.0-0 \
    && rm -rf /var/lib/apt/lists/*

# 兼容各种库/工具探测路径：给常见名字做软链
RUN ln -sf /usr/bin/chromium /usr/bin/chromium-browser && \
    ln -sf /usr/bin/chromium /usr/bin/google-chrome && \
    ln -sf /usr/bin/chromedriver /usr/bin/chromium-driver

# 给程序/依赖一个明确可用的路径（即使它不读也不影响）
ENV CHROME_BIN=/usr/bin/chromium \
    CHROMEDRIVER_BIN=/usr/bin/chromedriver

# Python 依赖
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# 后端代码
COPY . .

# 前端产物 -> 后端静态目录（本项目静态目录通常是 /app/static）
RUN rm -rf /app/static
COPY --from=frontend-builder /app/frontend/dist /app/static

# 启动脚本
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 本地默认 7860；Zeabur 会自动注入 PORT=8080（无需你手动设）
ENV PORT=7860
EXPOSE 7860

# 用 JSON 形式写 HEALTHCHECK（避免 CMD-SHELL 解析坑）
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD ["sh","-c","curl -fsS http://127.0.0.1:${PORT:-7860}/admin/health || exit 1"]

ENTRYPOINT ["/entrypoint.sh"]
