FROM node:20-alpine
WORKDIR /app
COPY package.json .
COPY cron-job.js .
ENV ORDERS_SERVICE_URL=http://orders-service:4003
CMD ["node", "cron-job.js"]
