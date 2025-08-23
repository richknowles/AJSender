FROM node:18-alpine

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production --silent
COPY . .

RUN mkdir -p data whatsapp-session uploads
RUN addgroup -g 1001 -S nodejs
RUN adduser -S ajsender -u 1001
RUN chown -R ajsender:nodejs /app
USER ajsender

EXPOSE 3001
CMD ["node", "server.js"]
