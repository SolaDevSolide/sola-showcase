# -------- base deps --------
FROM node:24-alpine AS base
ENV NODE_ENV=production
WORKDIR /app

# -------- builder --------
FROM base AS builder
ENV PNPM_HOME="/pnpm" PATH="$PNPM_HOME:$PATH"
RUN corepack enable

# Copy the manifest first (always present)
COPY package.json ./

# Copy lockfiles if they exist (wildcards are fine)
COPY pnpm-lock.yaml* yarn.lock* package-lock.json* .npmrc* ./

# install deps with the detected package manager
RUN if [ -f pnpm-lock.yaml ]; then corepack prepare pnpm@latest --activate; fi && \
    if [ -f pnpm-lock.yaml ]; then pnpm install --frozen-lockfile; \
    elif [ -f yarn.lock ]; then yarn --frozen-lockfile; \
    else npm ci; fi

COPY . .
RUN npm run build

# -------- runner --------
FROM node:24-alpine AS runner
ENV NODE_ENV=production
WORKDIR /app

# non-root
RUN addgroup -g 1001 -S nodejs && adduser -S nextjs -u 1001

# static/public
COPY --from=builder /app/public ./public
# standalone server output
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/next.config.ts ./next.config.ts

ENV PORT=3000
EXPOSE 3000
USER nextjs

# healthcheck matche API
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 CMD \
    wget -qO- http://127.0.0.1:${PORT}/api/health || exit 1

CMD ["node", "server.js"]