FROM node:20-alpine
WORKDIR /app
COPY package.json .
RUN npm install --omit=dev
COPY server.js .
COPY public ./public
ENV PORT=4000
EXPOSE 4000
HEALTHCHECK --interval=10s --timeout=3s --retries=3 CMD wget -qO- http://localhost:4000/health || exit 1
CMD ["node", "server.js"]
