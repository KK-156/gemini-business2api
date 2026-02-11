# Stage 1: 构建前端
FROM node:20-slim AS frontend-builder
WORKDIR /app/frontend
COPY frontend/package*.json ./
RUN npm install
COPY frontend/ ./
RUN npm run build

# Stage 2: 构建 Python 依赖
FROM python:3.11-slim AS python-builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Stage 3: 最终运行环境
FROM python:3.11-slim
WORKDIR /app

# 安装系统依赖：包含 chromium + xvfb + curl
RUN apt-get update && apt-get install -y --no-install-recommends \
    chromium \
    chromium-driver \
    xvfb \
    libnss3 \
    libxss1 \
    libasound2 \
    libatk-bridge2.0-0 \
    libgtk-3-0 \
    libdrm2 \
    libgbm1 \
    libxshmfence1 \
    libxcb-dri3-0 \
    libxcomposite1 \
    libxcursor1 \
    libxi6 \
    libxtst6 \
    fonts-liberation \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 拷贝 Python 依赖
COPY --from=python-builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=python-builder /usr/local/bin /usr/local/bin

# 拷贝后端代码
COPY . .

# 拷贝前端构建产物到 static（按你的项目结构）
RUN rm -rf static/dist && mkdir -p static/dist
COPY --from=frontend-builder /app/frontend/dist static/dist

# ---- 关键：适配 Zeabur 的 PORT=8080 ----
ENV HOST=0.0.0.0
ENV PORT=8080

# （可选但常用）给自动化浏览器一个明确路径，避免“找不到浏览器可执行文件”
ENV CHROME_PATH=/usr/bin/chromium
ENV CHROMIUM_PATH=/usr/bin/chromium
ENV BROWSER_PATH=/usr/bin/chromium

EXPOSE 8080

# 健康检查：使用 PORT 环境变量（Zeabur 会注入）
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
  CMD-SHELL curl -fsS "http://127.0.0.1:${PORT:-8080}/admin/health" || exit 1

RUN chmod +x /app/entrypoint.sh

CMD ["/app/entrypoint.sh"]
