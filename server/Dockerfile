# Stage 1: Build the application
FROM node:20-alpine AS builder

WORKDIR /app

# Copy the shared types first since the server depends on it locally
COPY shared/shared-types ./shared/shared-types
COPY shared/workflows ./shared/workflows

# Copy server package files and install all dependencies (including devDependencies for build)
COPY server/package.json server/package-lock.json ./server/
WORKDIR /app/server
RUN npm ci

# Copy server source files
COPY server/tsconfig.json ./
COPY server/src ./src

# Compile TypeScript
RUN npm run build

# Stage 2: Production runner
FROM node:20-alpine AS runner

WORKDIR /app

# Set production environment flags
ENV NODE_ENV=production
ENV PORT=4000

# Copy shared types for runtime resolution
COPY shared/shared-types ./shared/shared-types
COPY shared/workflows ./shared/workflows

# Copy package files and install ONLY production dependencies
COPY server/package.json server/package-lock.json ./server/
WORKDIR /app/server
RUN npm ci --only=production

# Copy compiled JavaScript from builder stage
COPY --from=builder /app/server/dist ./dist

# Expose port
EXPOSE 4000

# Start Express server
CMD ["node", "dist/server.js"]
