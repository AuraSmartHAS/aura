# ⚛️ AURA Care-Chain — App React Native (Expo)

Reimplementação do **fluxo crítico** do AURA em React Native, consumindo a mesma API
REST (Spring Boot, `../backend-spring`) do app Flutter e do painel Angular.

É a experimentação da nova stack proposta nesta fase: em vez de descartar o app
Flutter, o time recriou em RN o caminho que mais importa — **entrar → ver o risco
explicado → aprovar a recomendação → acompanhar a entrega** — para comparar as duas
stacks com evidência de código, não com opinião.

## ▶️ Como rodar

```bash
# 1. suba a API
cd ../backend-spring && ./mvnw spring-boot:run

# 2. rode o app
npm install
npm run web        # navegador (o mais rápido para demonstrar)
npm run ios        # simulador iOS
npm run android    # emulador Android
```

Login de demonstração: `ana@aura.com` / `aura1234`.

> Em **device físico**, troque o host em `src/api.ts` pelo IP da máquina — `localhost`
> no aparelho aponta para o próprio aparelho. No emulador Android o app já usa `10.0.2.2`.

## 📱 Telas

| Tela | Arquivo | O que faz |
|---|---|---|
| Login | `src/screens/LoginScreen.tsx` | `Image` (logo), `TextInput`, `Button` e estado de carregamento/erro |
| Painel da cuidadora | `src/screens/DashboardScreen.tsx` | risco por dimensão com barra, fatores e pesos; recalcular escore; registrar quase-queda |
| Care-Chain | `src/screens/CareChainScreen.tsx` | recomendação explicada, aprovação e linha do tempo do pedido |

## 🧩 Como está montado

- **Componentes funcionais** com hooks (`useState`, `useEffect`, `useCallback`) —
  `View`, `Text`, `Image`, `Button`, `TextInput`, `ScrollView`, `ActivityIndicator`.
- **React Navigation** (native stack) com rotas tipadas em `src/navigation.ts`.
- **`src/api.ts`** concentra o `fetch` com o Bearer e traduz o envelope de erro da API
  (`{"error":{"code","message"}}`) em mensagem de tela.
- **`src/theme.ts`** repete a paleta do app Flutter e do painel Angular, para as três
  superfícies parecerem o mesmo produto.
