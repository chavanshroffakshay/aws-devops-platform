# Multi-stage, non-root, minimal image
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev

FROM node:20-alpine
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY server.js ./
ENV PORT=3000
EXPOSE 3000
USER node
CMD ["node", "server.js"]
