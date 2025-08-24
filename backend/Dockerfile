FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install --omit=dev

# Copy source code
COPY . .

# Create necessary directories
RUN mkdir -p data whatsapp-session uploads

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S ajsender -u 1001 -G nodejs && \
    chown -R ajsender:nodejs /app

USER ajsender

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3001/health || exit 1

EXPOSE 3001

CMD ["node", "server.js"]
