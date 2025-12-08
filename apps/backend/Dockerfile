FROM node:20-slim AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable

# 1. Prune
FROM base AS pruner
WORKDIR /app
RUN npm install -g turbo
COPY . .
RUN turbo prune --scope=backend --docker

# 2. Installer
FROM base AS installer
WORKDIR /app
RUN apt-get update -y && apt-get install -y openssl

COPY --from=pruner /app/out/json/ .
COPY --from=pruner /app/out/yarn.lock ./yarn.lock
RUN yarn install --frozen-lockfile

COPY --from=pruner /app/out/full/ .
RUN npx prisma generate --schema=packages/db/prisma/schema.prisma

# Build
RUN yarn turbo run build --filter=backend...

RUN mkdir -p apps/backend/dist

RUN cp -v node_modules/.prisma/client/libquery_engine-debian-openssl-3.0.x.so.node apps/backend/dist/

# 3. Runner
FROM base AS runner
WORKDIR /app
RUN apt-get update -y && apt-get install -y openssl

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 expressjs
USER expressjs

COPY --from=installer /app .

CMD ["node", "apps/backend/dist/index.js"]