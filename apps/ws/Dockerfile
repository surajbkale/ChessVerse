# Multi-stage build for ws server
FROM node:18-alpine AS base

WORKDIR /app

COPY package.json yarn.lock turbo.json tsconfig.json ./
COPY packages ./packages
COPY apps ./apps

RUN corepack enable && yarn install --frozen-lockfile

# Generate Prisma client for @repo/db
RUN npx prisma generate --schema=packages/db/prisma/schema.prisma

# Build ws (bundle TypeScript with esbuild)
WORKDIR /app
RUN npx esbuild apps/ws/src/index.ts --bundle --platform=node --outfile=apps/ws/dist/index.js

FROM node:18-alpine AS runtime
WORKDIR /app

RUN apk add --no-cache openssl

ENV NODE_ENV=production

COPY --from=base /app/node_modules /app/node_modules
COPY --from=base /app/packages /app/packages
COPY --from=base /app/apps/ws/dist ./dist
COPY --from=base /app/apps/ws/package.json ./package.json

EXPOSE 8080
CMD ["node", "dist/index.js"]


