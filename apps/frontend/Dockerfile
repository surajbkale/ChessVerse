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

# 1. DELETE the default Nginx config
RUN rm /etc/nginx/conf.d/default.conf

# 2. COPY your custom config
COPY apps/frontend/nginx.conf /etc/nginx/conf.d/default.conf

# 3. Copy the React build files
COPY --from=build /app/apps/frontend/dist /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]