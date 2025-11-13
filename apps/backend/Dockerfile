# Multi-stage build for backend
FROM node:18-alpine AS base

WORKDIR /app

# Install dependencies using workspaces
COPY package.json yarn.lock turbo.json tsconfig.json ./
COPY packages ./packages
COPY apps ./apps

RUN corepack enable && yarn install --frozen-lockfile

# Generate Prisma client for @repo/db
RUN npx prisma generate --schema=packages/db/prisma/schema.prisma

# Build backend
WORKDIR /app/apps/backend
RUN npm run build

# Runtime image
FROM node:18-alpine AS runtime
WORKDIR /app

ENV NODE_ENV=production

# Copy built artifacts and node_modules
COPY --from=base /app/node_modules /app/node_modules
COPY --from=base /app/packages /app/packages
COPY --from=base /app/apps/backend/dist ./dist
COPY --from=base /app/apps/backend/package.json ./package.json

EXPOSE 3000
CMD ["node", "dist/index.js"]


