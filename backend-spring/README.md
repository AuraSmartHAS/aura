# ☕ AURA Care-Chain — API (Java + Spring Boot)

Backend REST do AURA Care-Chain. Serve os **três clientes** do projeto com o mesmo
contrato: app **Flutter**, app **React Native** (`../mobile-rn`) e painel **Angular**
(`../web-admin`).

| Item | Valor |
|---|---|
| Stack | Java 21 · Spring Boot 3.3 (Web MVC, Data JPA, Security, Validation, Thymeleaf) |
| Banco | H2 em memória (perfil `dev`, com seed) · PostgreSQL (perfil `postgres`) |
| Auth | JWT (HS256) — access 30 min + refresh 7 dias, stateless |
| Docs | Swagger UI em `/swagger-ui.html` · OpenAPI em `/v3/api-docs` |
| Prefixo | `/api/v1` |

## ▶️ Como rodar

```bash
./mvnw spring-boot:run
# API      → http://localhost:8080/api/v1
# Swagger  → http://localhost:8080/swagger-ui.html
# Status   → http://localhost:8080/          (página Thymeleaf)
```

Contas criadas pelo seed (senha `aura1234`):

| E-mail | Papel | Para quê |
|---|---|---|
| `ana@aura.com` | cuidadora | fluxo completo do cuidado (já com consentimento aceito e a casa da Maria) |
| `admin@aura.com` | admin | Torre de Controle (`/api/v1/ops/kpis`) e CRUD do catálogo |
| `maria@aura.com` | paciente | perfil de voz |

Com PostgreSQL:

```bash
docker compose up -d
AURA_SEED=true ./mvnw spring-boot:run -Dspring-boot.run.profiles=postgres
```

## 🧪 Testes

```bash
./mvnw test
```

10 testes: motor de escore (fatores, pesos, faixas, guardrail de não-prescrição) e o
percurso ponta a ponta em MockMvc — consentimento → casa → sinal → escore →
recomendação → aprovação → pedido entregue, mais isolamento entre pacientes (403),
RBAC da Torre de Controle e validação de payload.

## 🗺️ Rotas

| Método | Rota | O que faz |
|---|---|---|
| `POST` | `/api/v1/auth/signup` · `login` · `refresh` | conta e tokens |
| `GET` | `/api/v1/auth/me` | usuário atual + se aceitou a política |
| `POST` | `/api/v1/consent` | aceite LGPD — **gate** de todo dado de saúde |
| `POST` `GET` | `/api/v1/homes` · `/homes/{id}` | casa do paciente (endereço via ViaCEP) |
| `PUT` | `/api/v1/homes/{id}/checklist` | itens de segurança que alimentam o escore |
| `POST` `GET` | `/api/v1/signals` · `/homes/{id}/signals` | sinais observados (voz, auto-relato, uso, wearable) |
| `POST` | `/api/v1/scores/recompute` | escore explicável (fatores + pesos + frase) |
| `GET` | `/api/v1/homes/{id}/scores` · `/scores/latest` | histórico e último por dimensão |
| `GET` | `/api/v1/catalog` · `/catalog/{sku}` | catálogo de acessibilidade (NBR 9050) |
| `POST` `PUT` `DELETE` | `/api/v1/catalog/{sku}` | CRUD do catálogo — **admin** |
| `POST` `GET` | `/api/v1/recommendations` · `/homes/{id}/recommendations` | recomendação explicada |
| `POST` | `/api/v1/recommendations/{id}/approve` · `reject` | aprovação humana (RN-022) |
| `POST` `GET` | `/api/v1/orders/{id}/advance` · `/orders/{id}` | cadeia logística e SLA |
| `GET` | `/api/v1/ops/kpis` | Torre de Controle — **admin** |
| `GET` | `/api/v1/health` · `/` | saúde do serviço · página Thymeleaf |

## 🧱 Arquitetura

```
web/          Controllers REST + DTOs + tratamento global de erro
service/      Regras de negócio (escore, care-chain, guardrails, geo, KPIs)
repository/   Spring Data JPA
domain/       Entidades + enums + conversores JSON
config/       Security (JWT), OpenAPI, propriedades e seed
resources/    application.yml · scoring-weights.yml · templates/status.html
```

**Os pesos do escore não estão no código.** Vivem em `scoring-weights.yml`,
versionados: mudar a política de risco é editar YAML, não recompilar. É o que
sustenta a promessa de explicabilidade.

## ⛔ Regras de negócio que o código garante

1. **Nunca prescreve nem diagnostica** — `GuardrailService` inspeciona todo texto
   que sai da API (`422 PRESCRIPTION_BLOCKED`).
2. **Gate LGPD** — sem consentimento, nenhum dado de saúde entra (`422 CONSENT_REQUIRED`).
3. **Isolamento por paciente** — casa de outro usuário responde `403`, não `404`.
4. **Nenhum pedido sem aprovação humana** — a recomendação só vira pedido quando a
   cuidadora aprova (RN-022).

## ⚠️ Envelope de erro

```json
{ "error": { "code": "CONSENT_REQUIRED", "message": "Aceite a Política…", "details": null } }
```

Códigos: `VALIDATION_ERROR` · `UNAUTHORIZED` · `TOKEN_EXPIRED` · `INVALID_CREDENTIALS` ·
`FORBIDDEN` · `NOT_FOUND` · `CONFLICT` · `CONSENT_REQUIRED` · `APPROVAL_REQUIRED` ·
`PRESCRIPTION_BLOCKED` · `SCORE_HOME_MISMATCH` · `NO_PRODUCT` · `UNKNOWN_DIMENSION` ·
`INTERNAL_ERROR`.
