# Dockerfile
ARG FROM_IMAGE
FROM ${FROM_IMAGE} AS builder

WORKDIR /app

COPY package.json ./

RUN npm install

COPY . .

RUN npm cache clean --force && \
    npm run build

# STAGE 2
FROM nginx:stable-alpine
COPY --from=builder /app/build /usr/share/nginx/html
COPY ./dockerfiles/nginx/nginx.conf /etc/nginx/conf.d/default.conf
