# App React Native rodando como web (janela C da demo) via servidor de dev do Expo.
# O JavaScript executa no navegador de quem assiste, então a API continua sendo
# http://localhost:8080 da máquina — a mesma porta publicada pelo backend do compose.
FROM node:20
WORKDIR /app
# libs que o React Native DevTools exige; sem elas o Metro loga um ERROR (inofensivo, mas
# assustador no palco) ao subir
RUN apt-get update && apt-get install -y --no-install-recommends libnspr4 libnss3 \
    && rm -rf /var/lib/apt/lists/*
COPY package*.json ./
RUN npm ci
COPY . .
ENV CI=1 EXPO_NO_TELEMETRY=1
EXPOSE 8081
CMD ["npx", "expo", "start", "--web", "--port", "8081"]
