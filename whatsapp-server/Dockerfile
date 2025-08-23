FROM node:18-alpine

RUN apk add --no-cache \
    chromium \
    nss \
    freetype \
    freetype-dev \
    harfbuzz \
    ca-certificates \
    ttf-freefont

WORKDIR /app

# Copy package files and install dependencies
COPY package*.json ./
RUN npm install

# Copy source code
COPY . .

# Build the TypeScript project
RUN npm run build

# Create session and logs directories with proper permissions
RUN mkdir -p /app/session /app/logs

# Create nodejs user and group
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nodejs -u 1001

# Give nodejs user ownership of the entire app directory
RUN chown -R nodejs:nodejs /app

# Set proper permissions for session directory
RUN chmod -R 755 /app/session
RUN chmod -R 755 /app/logs

# Switch to nodejs user
USER nodejs

EXPOSE 3002

CMD ["npm", "start"]
