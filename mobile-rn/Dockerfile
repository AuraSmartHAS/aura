# App React Native rodando como web (janela C da demo) via servidor de dev do Expo.
# O JavaScript executa no navegador de quem assiste, então a API continua sendo
# http://localhost:8080 da máquina — a mesma porta publicada pelo backend do compose.
FROM node:20
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
# O React Native DevTools é um binário Chrome de depuração que não roda (nem faz falta)
# dentro do container; o stub evita o ERROR vermelho do Metro na subida sem arrastar
# a árvore de dependências gráficas do Chrome para a imagem.
RUN BIN=node_modules/@react-native/debugger-shell/bin/react-native-devtools; \
    if [ -e "$BIN" ]; then printf '#!/bin/sh\nexit 0\n' > "$BIN" && chmod +x "$BIN"; fi
# EXPO_UNSTABLE_HEADLESS: dentro de container não há terminal interativo — e é o que faz o
# Expo pular a instalação do DevTools (binário Chrome que não roda aqui) na subida
ENV CI=1 EXPO_NO_TELEMETRY=1 EXPO_OFFLINE=1 EXPO_UNSTABLE_HEADLESS=1
EXPOSE 8081
# --offline: nada de rede na subida (nem tentativa de baixar DevTools) — a demo não pode
# depender do wi-fi do auditório para o Metro nascer limpo
CMD ["npx", "expo", "start", "--web", "--port", "8081", "--offline"]
