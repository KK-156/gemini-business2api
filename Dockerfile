# syntax=docker/dockerfile:1

############################
# 1) Build frontend
############################
FROM node:20-alpine AS frontend-builder
WORKDIR /app/frontend

COPY frontend/package*.json ./
RUN npm ci --omit=dev || npm install

COPY frontend/ ./
RUN npm run build \
 && mkdir -p /output \
 && if [ -d dist ]; then cp -r dist/* /output/; \
    elif [ -d build ]; then cp -r build/* /output/; \
    else echo "Frontend build output not found (dist/build)."; ls -la; exit 1; fi


############################
# 2) Runtime (backend + ui)
############################
FROM python:3.11-slim AS runtime
WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# ---- Install Chromium (more compatible) + common runtime libs ----
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    ca-certificates curl \
    chromium chromium-driver \
    xvfb xauth \
    fonts-liberation fonts-noto-cjk \
    libasound2 libcups2 libdbus-1-3 libdrm2 libgbm1 libgtk-3-0 \
    libnss3 libnspr4 \
    libx11-xcb1 libxcomposite1 libxdamage1 libxfixes3 libxrandr2 \
    libxkbcommon0 libxshmfence1 \
    libatk1.0-0 libatk-bridge2.0-0 \
    libpangocairo-1.0-0 libpango-1.0-0 libcairo2 \
    libxext6 libxrender1 libxss1 \
    libu2f-udev \
 && rm -rf /var/lib/apt/lists/* \
 # ---- make common aliases so different libs can find the browser ----
 && ln -sf /usr/bin/chromium /usr/bin/google-chrome \
 && ln -sf /usr/bin/chromium /usr/bin/chromium-browser

# Optional: expose browser path for libs that read env
ENV CHROME_PATH=/usr/bin/chromium \
    CHROME_BIN=/usr/bin/chromium \
    BROWSER_PATH=/usr/bin/chromium \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium

# ---- Python deps ----
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# ---- App code ----
COPY . .

# ---- Put frontend assets where backend is likely to serve ----
RUN mkdir -p /app/frontend/dist
COPY --from=frontend-builder /output /app/frontend/dist
RUN rm -rf /app/static && ln -s /app/frontend/dist /app/static

# ---- Entrypoint ----
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Zeabur usually routes to 8080; keep PORT overridable
ENV PORT=8080
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD curl -fsS "http://127.0.0.1:${PORT:-8080}/admin/health" || exit 1

ENTRYPOINT ["/entrypoint.sh"]
