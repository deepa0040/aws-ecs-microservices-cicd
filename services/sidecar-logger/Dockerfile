FROM node:20-alpine
WORKDIR /app
COPY package.json .
COPY sidecar.js .
ENV APP_HOST=localhost
ENV APP_PORT=4003
ENV SIDECAR_INTERVAL_MS=10000
CMD ["node", "sidecar.js"]
