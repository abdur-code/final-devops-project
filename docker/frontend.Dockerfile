# syntax=docker/dockerfile:1

FROM node:24-alpine AS build
WORKDIR /src
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY index.html vite.config.js ./
COPY src ./src
RUN npm run build

FROM nginxinc/nginx-unprivileged:1.30-alpine AS runtime
ARG GIT_SHA=dev
LABEL org.opencontainers.image.title="stockpilot-frontend" \
      org.opencontainers.image.revision="${GIT_SHA}"

USER root
RUN apk upgrade --no-cache
USER 101

ENV BACKEND_UPSTREAM=backend:8000 \
    NGINX_ENVSUBST_FILTER=BACKEND_
COPY nginx.conf.template /etc/nginx/templates/default.conf.template
COPY --from=build /src/dist /usr/share/nginx/html

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://127.0.0.1:8080/healthz || exit 1
