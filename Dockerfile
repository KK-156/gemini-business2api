services:
  gemini-api:
    build: .
    image: cooooookk/gemini-business2api:latest
    container_name: gemini-business2api

    ports:
      - "7860:7860"

    volumes:
      - ./data:/app/data

    env_file:
      - .env

    # 本地固定监听 7860（Zeabur 会给 8080，不影响）
    environment:
      - TZ=Asia/Shanghai
      - PORT=7860

      # （可选）如果你希望容器内所有请求默认走宿主机代理，打开下面三行即可
      # - HTTP_PROXY=http://host.docker.internal:8888
      # - HTTPS_PROXY=http://host.docker.internal:8888
      # - NO_PROXY=localhost,127.0.0.1,::1,host.docker.internal

    shm_size: "1g"

    extra_hosts:
      - "host.docker.internal:host-gateway"

    restart: unless-stopped

    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:7860/admin/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s

    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
