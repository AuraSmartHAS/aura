# Build do Angular numa etapa Node; publicação em nginx estático com fallback de SPA.
# O painel fala com a API em http://localhost:8080 — porta publicada pelo compose, então
# funciona direto no navegador de quem roda a demo, sem proxy nem variável de ambiente.
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npx ng build

FROM nginx:alpine
COPY --from=build /app/dist/web-admin/browser /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
