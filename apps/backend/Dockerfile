FROM node:20-slim AS base
ENV PNPM="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable

# Prune
FROM base AS pruner
WORKDIR /app
RUN npm install -g turbo
COPY . .
RUN turbo prune --scope=backend --docker

# install dependencies
FROM base AS  installer
WORKDIR /app

# Install OpenSSL for Prisma 
RUN apt-get update -y && apt-get install -y openssl

COPY --from=pruner /app/out/json/ .
COPY --from=pruner /app/out/yarn.lock ./yarn.lock
RUN yarn install --frozen-lockfile

COPY --from=pruner /app/out/full/ .

# Generate prisma client
RUN npx prisma generate --schema=packages/db/prisma/schema.prisma

# Build the backend
RUN yarn turbo run build --filter=backend...

FROM base AS runner
WORKDIR /app

RUN apg-get update -y && apt-get install -y openssl

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system -uid 1001 expressjs
USER expressjs

COPY --from=installer /app .

CMD [ "node", "apps/backend/dist/index.js" ]