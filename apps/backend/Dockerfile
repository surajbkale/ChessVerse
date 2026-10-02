FROM node:20-slim AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable

# ── 1. Prune — isolate backend workspace files ────────────────────────────────
FROM base AS pruner
WORKDIR /app
RUN npm install -g turbo
COPY . .
RUN turbo prune --scope=backend --docker

# ── 2. Installer — install deps and build ─────────────────────────────────────
FROM base AS installer
WORKDIR /app
# openssl required by Prisma client
RUN apt-get update -y && apt-get install -y openssl

COPY --from=pruner /app/out/json/ .
COPY --from=pruner /app/out/yarn.lock ./yarn.lock
RUN yarn install --frozen-lockfile

COPY --from=pruner /app/out/full/ .
# Generate Prisma client (produces the native .node engine binary)
RUN npx prisma generate --schema=packages/db/prisma/schema.prisma

# esbuild bundles all TS + node_modules into a single dist/index.js
RUN yarn turbo run build --filter=backend...

# ── 3. Runner — minimal production image ──────────────────────────────────────
# H4 fix: esbuild --bundle means node_modules are NOT needed at runtime.
# Only copy: the compiled bundle + the Prisma native engine binary.
FROM node:20-slim AS runner
WORKDIR /app

# openssl required by Prisma at runtime
RUN apt-get update -y && apt-get install -y openssl && rm -rf /var/lib/apt/lists/*

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 expressjs
USER expressjs

# Bundle — the only JS we need at runtime
COPY --from=installer --chown=expressjs:nodejs /app/apps/backend/dist ./apps/backend/dist

# Prisma native engine binary (must live alongside dist/ at the same relative path)
COPY --from=installer --chown=expressjs:nodejs /app/apps/backend/libquery_engine-debian-openssl-3.0.x.so.node ./apps/backend/

CMD ["node", "apps/backend/dist/index.js"]