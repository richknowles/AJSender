FROM node:18-alpine

# deps for Chromium driven by whatsapp-web.js/puppeteer
RUN apk add --no-cache \
    chromium \
    nss \
    freetype \
    harfbuzz \
    ca-certificates \
    ttf-freefont

ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

WORKDIR /app
COPY package*.json ./
RUN npm install --omit=dev
COPY . .

RUN mkdir -p sessions public/qr .wwebjs_auth .wwebjs_cache
RUN addgroup -g 1001 -S nodejs && adduser -S whatsapp -u 1001
RUN chown -R whatsapp:nodejs /app
USER whatsapp

EXPOSE 3002
CMD ["node","server.js"]
