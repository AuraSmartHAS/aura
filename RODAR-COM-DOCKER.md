# Rodar a demo em qualquer máquina (Docker)

Para quem vai apresentar sem esta máquina: **três comandos e a demo está de pé**, com o
mesmo seed, as mesmas contas e o mesmo cenário do ensaio. Só precisa do
[Docker Desktop](https://www.docker.com/products/docker-desktop/) instalado e aberto.

## Subir tudo

```bash
git clone https://github.com/AuraSmartHAS/aura.git
cd aura
docker compose up --build
```

A `main` já traz tudo: a Fase 5, o card de **reposição por consumo** no painel da Ana, a página de
**parceiros** e o **catálogo curado** (Leroy Merlin e rede parceira), que nasce no boot — nenhum
import manual. A entrega (pedido, estágios e mapa da última milha) vive nos apps, não no painel
web: saiu dele na D-008. Quem avança o estágio é a conta da Operação, no app React Native.

A conversa por voz da Maria (app Flutter) é opcional e usa o ElevenLabs: exporte
`ELEVENLABS_API_KEY` e `ELEVENLABS_AGENT_ID` antes do `docker compose up`. Sem elas o resto da demo
funciona, e o app responde "Não consegui me conectar agora" ao tocar no microfone.

A primeira execução baixa dependências e **demora alguns minutos** — faça isso em casa,
nunca na sala da apresentação. Das vezes seguintes sobe em segundos.

Pronto quando o log mostrar o `Seed pronto — login de demonstração...` do backend.

| Janela | Endereço | Conta |
|---|---|---|
| A — Painel da cuidadora | http://localhost:4200 → `/home` | `ana@aura.com` · `aura1234` |
| B — Torre de Controle | http://localhost:4200 → `/admin` (perfil de navegador separado) | `admin@aura.com` · `aura1234` |
| C — App React Native (opcional) | http://localhost:8081 | `ana@aura.com` já pré-preenchido |

A janela C exige subir com o perfil extra: `docker compose --profile rn up --build`.

## O botão de reset (T-15 min antes do palco)

O banco é em memória: **reiniciar o backend recompõe o cenário limpo**, com todos os
prazos relativos ao relógio (os pedidos voltam ao seed, o pedido apertado volta a "vence na
próxima hora"):

```bash
docker compose restart backend
```

Depois do restart os IDs mudam — **relogue as janelas A e B**. A sessão expira em 30
minutos de qualquer forma, então relogar perto da vez é regra, não exceção.

## Se algo der errado

| Sintoma | O que fazer |
|---|---|
| "port is already allocated" | Algo já usa 8080/4200/8081 na máquina: `lsof -nP -iTCP:8080 -sTCP:LISTEN` e encerre, ou feche o processo antigo do Docker (`docker compose down`) |
| Painel abre mas não loga | O backend ainda está subindo — espere o `Seed pronto` no log |
| Tela estranha/dados velhos | `docker compose restart backend` + relogin (reset completo do cenário) |
| Quero recomeçar do zero | `docker compose down && docker compose up --build` |

Roteiro de palco, contas e planos B cena a cena: `DEMO.md` e
`PLANO BRILHO LOGISTICA/05-ROTEIRO-APRESENTACAO-HOJE.md` (na pasta FIAP).

Catálogo curado (opcional, muda a tela do catálogo — só depois de decidir no ensaio):
`python3 importar-catalogo.py` com o backend de pé.
