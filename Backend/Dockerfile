# Stage 1: install dependencies
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY . .

# Stage 2: production image
FROM node:20-alpine
WORKDIR /app
COPY --from=builder /app .
USER node
EXPOSE 3001
CMD ["node", "index.js"]
