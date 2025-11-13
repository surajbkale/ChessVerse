# Build and serve static frontend with nginx
FROM node:18-alpine AS build
WORKDIR /app

COPY package.json yarn.lock turbo.json tsconfig.json ./
COPY packages ./packages
COPY apps ./apps

RUN corepack enable && yarn install --frozen-lockfile

WORKDIR /app/apps/frontend
RUN npm run build

FROM nginx:alpine AS runtime
COPY --from=build /app/apps/frontend/dist /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
