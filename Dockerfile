# ── Build stage ──────────────────────────────────────────────
FROM node:20-slim AS builder

WORKDIR /app

# Install OpenSSL for Prisma
RUN apt-get update -y && apt-get install -y openssl && rm -rf /var/lib/apt/lists/*

# Install deps
COPY package.json package-lock.json* ./
RUN npm ci

# Copy source & prisma
COPY tsconfig.json ./
COPY src/ ./src/
COPY prisma/ ./prisma/

# Generate Prisma client & compile TS
RUN npx prisma generate
RUN npm run build

# ── Production stage ────────────────────────────────────────
FROM node:20-slim AS runner

WORKDIR /app

RUN apt-get update -y && apt-get install -y openssl && rm -rf /var/lib/apt/lists/*

# Install production deps only
COPY package.json package-lock.json* ./
RUN npm ci --omit=dev

# Copy compiled JS + Prisma
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma
COPY prisma/ ./prisma/

# Environment
ENV NODE_ENV=production
ENV PORT=3000

EXPOSE 3000

# Run migrations then start
CMD ["sh", "-c", "npx prisma migrate deploy && node dist/server.js"]
