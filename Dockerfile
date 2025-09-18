# -------- base deps --------
FROM node:24-alpine AS base
ENV NODE_ENV=production
WORKDIR /app
RUN apk add --no-cache libc6-compat

# -------- dev (for VS Code / next dev) --------
FROM node:24-alpine AS dev
ENV NODE_ENV=development
WORKDIR /app
ENV PNPM_HOME="/pnpm" PATH="$PNPM_HOME:$PATH"
RUN corepack enable

# Copy only manifests first
COPY package.json ./
COPY pnpm-lock.yaml* yarn.lock* package-lock.json* .npmrc* ./

# Install WITH dev dependencies
RUN if [ -f pnpm-lock.yaml ]; then corepack prepare pnpm@latest --activate; fi && \
    if [ -f pnpm-lock.yaml ]; then pnpm install; \
    elif [ -f yarn.lock ]; then yarn; \
    else npm install; fi

# Bring in source (no build here)
COPY . .

# -------- builder (for CI/prod build) --------
FROM base AS builder
# IMPORTANT: temporarily use dev env to include dev deps during build tooling
ENV NODE_ENV=development
ENV PNPM_HOME="/pnpm" PATH="$PNPM_HOME:$PATH"
RUN corepack enable

COPY package.json ./
COPY pnpm-lock.yaml* yarn.lock* package-lock.json* .npmrc* ./

RUN if [ -f pnpm-lock.yaml ]; then corepack prepare pnpm@latest --activate; fi && \
    if [ -f pnpm-lock.yaml ]; then pnpm install --frozen-lockfile; \
    elif [ -f yarn.lock ]; then yarn --frozen-lockfile; \
    else npm ci; fi

COPY . .
RUN npm run build

# -------- runner (production) --------
FROM node:24-alpine AS runner
ENV NODE_ENV=production
WORKDIR /app

RUN addgroup -g 1001 -S nodejs && adduser -S nextjs -u 1001

COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/next.config.ts ./next.config.ts

ENV PORT=3000
EXPOSE 3000
USER nextjs

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 CMD \
    wget -qO- http://127.0.0.1:${PORT}/api/health || exit 1

CMD ["node", "server.js"]    