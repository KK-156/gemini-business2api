# Stage 1: Build frontend assets
FROM node:20-alpine AS frontend-builder

WORKDIR /app/frontend
COPY frontend/package*.json ./
RUN npm install
COPY frontend/ .
RUN npm run build

# Stage 2: Build backend and serve frontend
FROM python:3.11-slim AS backend

WORKDIR /app

# Install system dependencies for Chrome and Playwright
RUN apt-get update && apt-get install -y \
    curl \
    xvfb \
    libnss3 \
    libatk-bridge2.0-0 \
    libdrm2 \
    libxkbcommon0 \
    libgbm1 \
    libasound2 \
    libxrandr2 \
    libxfixes3 \
    libxcomposite1 \
    libxdamage1 \
    libxext6 \
    libxshmfence1 \
    libx11-xcb1 \
    libxcb1 \
    libglib2.0-0 \
    libgtk-3-0 \
    libcairo2 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy backend source
COPY . .

# Copy built frontend assets
COPY --from=frontend-builder /app/static ./static

# Make entrypoint executable
RUN chmod +x /app/entrypoint.sh

# ✅ Zeabur 通常会注入 PORT；这里给一个默认值，方便本地/兼容
ENV PORT=8080
ENV HOST=0.0.0.0

# ✅ Zeabur 的公网暴露口通常是 8080（或你设置的 PORT）
EXPOSE 8080

# ✅ 健康检查一定要打到“实际监听的端口”
# 用 shell 形式，才能展开 ${PORT}
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
  CMD curl -fsS "http://127.0.0.1:${PORT:-8080}/admin/health" || exit 1

ENTRYPOINT ["/app/entrypoint.sh"]
