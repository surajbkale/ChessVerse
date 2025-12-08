FROM node:20-slim AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable

# Prune
FROM base AS pruner
WORKDIR /app
RUN npm install -g turbo
COPY . .
RUN turbo prune --scope=frontend --docker

# Builder
FROM base AS builder
WORKDIR /app
COPY --from=pruner /app/out/json/ .
COPY --from=pruner /app/out/yarn.lock ./yarn.lock
RUN yarn install --frozen-lockfile

COPY --from=pruner /app/out/full/ .

# --- BUILD ARGUMENTS ---
# Passed from GitHub Actions
ARG VITE_APP_BACKEND_URL
ARG VITE_APP_WS_URL
ENV VITE_APP_BACKEND_URL=$VITE_APP_BACKEND_URL
ENV VITE_APP_WS_URL=$VITE_APP_WS_URL

RUN yarn turbo run build --filter=frontend...

# Runner (Nginx)
FROM nginx:alpine AS runner
# Copy custom nginx config (Created in next step)
COPY apps/frontend/nginx.conf /etc/nginx/conf.d/default.conf
# Copy built static files
COPY --from=builder /app/apps/frontend/dist /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]