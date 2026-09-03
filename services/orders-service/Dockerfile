FROM node:20-alpine
WORKDIR /app
COPY package.json .
RUN npm install --omit=dev
COPY server.js .
ENV PORT=4003
EXPOSE 4003
HEALTHCHECK --interval=10s --timeout=3s --retries=3 CMD wget -qO- http://localhost:4003/health || exit 1
CMD ["node", "server.js"]
