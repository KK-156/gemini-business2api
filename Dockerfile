# Stage 1: 构建前端
FROM node:20-slim AS frontend-builder
WORKDIR /app/frontend
COPY frontend/package*.json ./
RUN npm ci
COPY frontend/ ./
RUN npm run build

# Stage 2: 构建后端
FROM python:3.11-slim
WORKDIR /app

# 安装系统依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    chromium \
    chromium-driver \
    xvfb \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 复制后端代码
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .

# 复制前端构建产物
COPY --from=frontend-builder /app/frontend/dist /app/frontend/dist

# 复制并赋权启动脚本
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Zeabur 固定容器端口 8080
EXPOSE 8080

# ✅ Dockerfile 的 HEALTHCHECK 只能是 CMD / NONE（不要 CMD-SHELL）
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
  CMD curl -fsS http://127.0.0.1:8080/admin/health || exit 1

CMD ["/app/entrypoint.sh"]
