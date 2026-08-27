# ☕ AURA Care-Chain — API (Java + Spring Boot)

Backend REST do AURA Care-Chain. Serve os **três clientes** do projeto com o mesmo
contrato: app **Flutter**, app **React Native** (`../mobile-rn`) e painel **Angular**
(`../web-admin`).

| Item | Valor |
|---|---|
| Stack | Java 21 · Spring Boot 3.3 (Web MVC, Data JPA, Security, Validation, Thymeleaf) |
| Banco | H2 em memória (perfil `dev`, com seed) · PostgreSQL (perfil `postgres`) |
| Auth | JWT (HS256) — access 30 min + refresh 7 dias, stateless |
| Docs | Swagger UI em `/swagger-ui.html` · OpenAPI em `/v3/api-docs` · versão offline em [`../docs/api/aura-api.html`](../docs/api/aura-api.html) |
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

23 testes: motor de escore (fatores, pesos, faixas, guardrail de não-prescrição),
o percurso ponta a ponta em MockMvc — consentimento → casa → sinal → escore →
recomendação → aprovação → pedido entregue — e o ciclo de vida da medicação,
incluindo a confirmação de dose que vira sinal de adesão. Mais isolamento entre
pacientes (403), RBAC da Torre de Controle e validação de payload.

> Requer **JDK 21**. Se `./mvnw` reclamar de "Unable to locate a Java Runtime" no
> macOS, instale com `brew install openjdk@21` e exporte antes de rodar:
> `export JAVA_HOME=/opt/homebrew/opt/openjdk@21 && export PATH="$JAVA_HOME/bin:$PATH"`

## 📘 Documentação da API

O Swagger é gerado do código (springdoc), com o botão **Authorize** já configurado para o JWT —
dá para rodar o fluxo inteiro pelo navegador. Cada operação documenta **todas as respostas de
erro** que pode devolver, com exemplo do envelope padrão: as comuns (401/403/404/500) entram por
um `OpenApiCustomizer`, e as de negócio (409, 422 `CONSENT_REQUIRED`, `APPROVAL_REQUIRED`,
`NO_PRODUCT`, 400 `UNKNOWN_DIMENSION`) só aparecem nas rotas que realmente as produzem.

Para regerar o contrato e a página offline depois de mudar a API:

```bash
curl -s http://localhost:8080/v3/api-docs | python3 -m json.tool > ../docs/api/openapi.json
python3 ../docs/api/gerar_doc.py ../docs/api/openapi.json ../docs/api/aura-api.html
```

> ⚠️ **Não use `npx @redocly/cli build-docs` para gerar o `aura-api.html`.** Ele
> produz uma página que baixa o renderizador de `cdn.redocly.com`: aberta sem
> internet, fica em branco — e esse arquivo vai dentro do ZIP da entrega, que
> precisa funcionar localmente. O `gerar_doc.py` gera HTML autocontido.

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
| `POST` `GET` | `/api/v1/homes/{id}/medications` | medicações do paciente |
| `PUT` `DELETE` | `/api/v1/medications/{id}` | edita e remove |
| `POST` | `/api/v1/medications/{id}/confirm` | confirma a dose → grava sinal de adesão |
| `POST` `GET` | `/api/v1/orders/{id}/advance` · `/orders/{id}` | cadeia logística, rota da entrega e SLA |
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
