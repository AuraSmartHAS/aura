# 🌅 AURA Care-Chain

> Para retomar trabalho de engenharia, comece por [START-HERE.md](START-HERE.md). A memória e o protocolo de tasks ficam em [ROADMAP.md](ROADMAP.md) e [AGENTS.md](AGENTS.md); tarefas TODO não iniciam sem ordem humana explícita.

> Smart HAS · Enterprise Challenge 2026 (mentoria Leroy Merlin) · **FIAP — Sociedade 5.0**
> Assistente de saúde domiciliar **voice-first** para idosos com Parkinson +
> **cadeia logística de segurança da casa**, com recomendação sempre explicada.
> Duas personas, duas superfícies: **Maria** (paciente, fala com o app) e
> **Ana** (cuidadora, acompanha tudo pelo painel).

## 📦 Monorepo

| Pasta | Stack | O que é |
|---|---|---|
| [`mobile/`](mobile/) | Flutter (Dart) | App principal — Android, iOS e Web. Voz para a Maria, painel para a Ana |
| [`mobile-rn/`](mobile-rn/) | React Native (Expo) | Fluxo crítico recriado na nova stack: login → risco explicado → aprovação → entrega |
| [`backend-spring/`](backend-spring/) | Java 21 + Spring Boot 3.3 | API REST `/api/v1` com JWT, JPA, Swagger e página Thymeleaf |
| [`web-admin/`](web-admin/) | Angular 20 | Painel da cuidadora e Operação (administrador) |
| [`database/oracle/`](database/oracle/) | Oracle PL/SQL | Dados simulados, consultas de demonstração e instalação por script (Fase 6) |

Os **três clientes consomem exatamente a mesma API**. O contrato é o ponto de
encontro do projeto: mudar de stack no mobile não muda o backend, e vice-versa.

```
 Flutter (Android/iOS/Web) ┐                              ┌ H2 (testes)
 React Native (Expo)       ├──► Spring Boot /api/v1 ───────┼ PostgreSQL (ensaio)
 Angular (painel web)      ┘    JWT · JPA · Swagger        └ Oracle + PL/SQL (Fase 6)
```

O mesmo back-end roda nos três bancos trocando só o perfil; cada um tem suas migrations em
`backend-spring/src/main/resources/db/migration/{postgresql,oracle}`.

## ⛔ Regras de ouro (nunca violar)
1. **Nunca prescreve/diagnostica** — não é dispositivo médico; sintoma relevante é sempre encaminhado ao médico.
2. **Sem sensores IoT** — o monitoramento vem do próprio app + wearable leve (Health Connect / HealthKit).
3. **Acessibilidade WCAG 2.1 AA, voice-first** — microfone gigante, texto grande, alvos ≥48dp e fallback de teclado sempre disponível.
4. **LGPD desde o desenho** — gate de consentimento antes de qualquer dado de saúde, JWT em storage seguro, exclusão pelo servidor.
5. **Inteligência explicável** — todo escore de risco mostra os fatores e os pesos que o produziram.

## 🚀 Subir tudo localmente

```bash
# 1. API (porta 8080) — sem Docker, banco H2 com dados de demonstração
cd backend-spring && ./mvnw spring-boot:run

# 2. Painel Angular (porta 4200)
cd web-admin && npm install && npm start

# 3. App React Native (porta 8081)
cd mobile-rn && npm install && npm run web

# 4. App Flutter
cd mobile && cp .env.example .env && flutter pub get && flutter run -d chrome
```

Contas de demonstração (senha `aura1234`): `ana@aura.com` (cuidadora),
`admin@aura.com` (Operação), `maria@aura.com` (paciente).

## 🗄️ Sobre Oracle, com PL/SQL (Fase 6)

```bash
export AURA_DB_PASSWORD='uma-senha-sua'
docker compose -f docker-compose.yml -f docker-compose.oracle.yml up --build -d
./database/oracle/carregar-dados.sh   # CSV da pulseira (SQL*Loader) + carga simulada
```

O Flyway cria 16 tabelas, 3 functions e 3 procedures (mais 3 rotinas de apoio); a cada leitura nova o back-end chama
`PRC_REGISTRAR_ALERTAS` por JDBC, depois do commit, e o aviso aparece no painel da cuidadora.
Detalhes, DER e consultas de demonstração: [`database/oracle/README.md`](database/oracle/README.md)
e [`docs/fase6/documentacao.html`](docs/fase6/documentacao.html).

Testes: `./mvnw test` (H2, rápido) · `./mvnw test -Dtest.groups=oracle -Dtest.excludedGroups=`
(Oracle real via Testcontainers) · `./mvnw test -Dtest.groups=postgres -Dtest.excludedGroups=`
(PostgreSQL).

> A coluna `scores.level` virou `risk_level` (migration V3 no PostgreSQL). Um banco PostgreSQL
> local migrado por esta versão não valida mais com o código anterior a ela.

## 🗺️ Telas do app Flutter

### Maria — paciente (voz)
| Rota | O que acontece |
|---|---|
| `/voice` | **Home de voz (VUI)**: microfone gigante, transcrição ao vivo e fallback de teclado. É por conversa que Maria registra **sintomas**, confirma a **medicação** do dia e pede **ajuda/emergência**. |

### Ana — cuidadora (painel)
| Rota | Feature | O que acontece |
|---|---|---|
| `/onboarding` | `home_setup` | Cadastro da casa (CEP) + checklist de segurança |
| `/dashboard` | `caregiver_dashboard` | Status do dia da Maria num olhar |
| `/wellbeing` | `wellbeing360` | **Bem-estar 360**: sinais de saúde e humor ao longo do tempo |
| `/carechain` | `carechain` | **Care-Chain**: recomendação com risco + fatores + motivo, e o botão de aprovar |
| `/orders/:id` | `orders` | Detalhe e linha do tempo do pedido |
| `/map/:orderId` | `delivery_map` | **Mapa da entrega** (Google Maps) com ETA |
| `/medications` | `medications` | CRUD de medicamentos + lembretes |
| `/wearable` | `wearable` | Conectar o wearable e sincronizar sinais |

### Compartilhadas
`/login` · `/signup` · `/consent` (gate LGPD) · `/credits`

## 🧱 Arquitetura do app Flutter

```
UI (pages/widgets) ──> BLoC (por feature) ──> UseCases ──> Repositories
                              │ dio + JWT ──> API /api/v1
                              │ drift ─────> banco local (SQLite)
                              │ health ────> wearable (HC/HealthKit)
                              │ FCM ───────> push
```

**BLoC por feature** com camadas `data / domain / presentation`, **go_router** com
guards de sessão, **get_it** para injeção de dependência.

## 👥 Equipe

| Nome | RM | Papel |
|---|---|---|
| Vinícius Miranda Baptista | 555081 | Tech Lead |
| João Domingos Góes Filho | 564465 | Dev Senior Mobile |
| Pedro Henrique Arenas Negri | 554971 | Dev Pleno |
| Júlia Alves Dias | 557151 | Infra |

## 🔗 Links
- **Backend da fase anterior (FastAPI):** [github.com/AuraSmartHAS/aura-server](https://github.com/AuraSmartHAS/aura-server)
- **Figma:** [AURA — design](https://www.figma.com/design/vEyinUEawJndUsIAMlJJGc/AURA)
