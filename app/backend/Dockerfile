# ── Stage 1: dependencies ──────────────────────────────────
FROM node:25.8.2-alpine3.23 AS deps

WORKDIR /app

# Copy manifests first for layer caching
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# ── Stage 2: test (optional, run in CI) ────────────────────
FROM node:25.8.2-alpine3.23 AS test

WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm test -- --passWithNoTests

# ── Stage 3: production image ───────────────────────────────
FROM node:25.8.2-alpine3.23 AS production

LABEL maintainer="scubik"
LABEL app="devtracker-backend"

# Security: run as non-root
RUN addgroup -g 1001 -S nodejs && \
    adduser  -S nodeuser -u 1001 -G nodejs

WORKDIR /app

# Copy production deps from deps stage
COPY --from=deps --chown=nodeuser:nodejs /app/node_modules ./node_modules

# Copy application source
COPY --chown=nodeuser:nodejs src/ ./src/
COPY --chown=nodeuser:nodejs package.json ./

USER nodeuser

EXPOSE 4000

# Kubernetes health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD wget -qO- http://localhost:4000/health || exit 1

CMD ["node", "src/index.js"]
