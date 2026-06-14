# Plano — Implementação das features restantes do Aura (mobile: Paciente + Familiar)

## Context

O app Aura Care-Chain capta sinais de risco do idoso e dispara a cadeia logística
(recomendação → pedido → entrega → instalação) **antes do acidente**. Hoje o app Flutter
(`mobile/`) tem só: auth via **Firebase**, a **Home de voz** (ElevenLabs) da paciente Maria,
e uma página de créditos. Toda a jornada-herói da cuidadora (Ana) — onboarding da casa,
monitoramento 360, escore explicável, Care-Chain, pedido, mapa, wearable e push — ainda
não existe.

O backend real (`aura-server`, contrato em `…/aura-server/docs/API.md`) já expõe todos os
endpoints REST sob `/api/v1`, com **auth JWT própria** e papéis (`paciente`, `cuidadora`,
`profissional`, `admin`). Este plano cobre **apenas as superfícies mobile (Paciente + Familiar)**;
as superfícies web (Portal Pessoa / Torre de Controle Admin) ficam para uma fase posterior.

### Decisões fechadas com o usuário
1. **Auth:** migrar de Firebase Auth → **JWT do aura-server** (`/auth/login` devolve `token` +
   `refreshToken` + `role`). Manter `firebase_core` **só para FCM**.
2. **Backend:** REST real disponível. Construir datasources com `dio` contra `BASE_URL/api/v1`.
3. **Config/segredos:** tudo em um **`.env`** (no `.gitignore`); onde faltar chave, deixar placeholder.
4. **Conectividade:** incluir **Mapa + rastreador**, **Wearable (`health`)** e **Push FCM**.
5. **Fluxos de voz da paciente** (sintoma, confirmar remédio, emergência): conduzidos **pelo agente
   de voz** (tools/intents) — não viram telas dedicadas. A Home de voz atual permanece.
6. **Perfil + LGPD:** incluir roteamento por papel + **gate de consentimento** (`POST /consent`, RN-001).
7. **Onboarding da casa:** incluir (cuidadora cadastra casa via CEP + checklist de segurança).
8. **Medicamentos:** apenas o **lado da cuidadora** (cadastrar remédios do parente). A API não tem
   rotas de medicamento → implementar local (Drift) **e gerar um doc propondo a API** p/ o server adicionar depois.

### Achado crítico
A API usa **camelCase** em tudo, modelo de **erro único** (`{ "error": { "code", "message", "details" } }`)
e um **gate de consentimento (422 `CONSENT_REQUIRED`)** em `POST /homes`, `/signals`, `/scores/recompute`,
`/recommendations`. Isso dirige o design do interceptor de erros e do fluxo de onboarding.

---

## Padrões a reusar (já no projeto — `mobile/CLAUDE.md`)
- **Clean Arch por feature** (`data/domain/presentation/di`), **BLoC** (1 por feature), **go_router**, **get_it**.
- **`Result<T>`** (`core/errors/result.dart`) + `AppFailure` (`core/errors/app_failure.dart`): `try/catch` só em `data`.
- **Freezed** para entities/models; rodar `dart run build_runner build --delete-conflicting-outputs` após mudanças.
- **DI por módulo** (`feature/di/setupXModule(sl)`), agregados em `core/di/service_locator.dart`.
- **Page/Body split**; nenhuma cor hardcoded (usar `Theme`/tokens); identificadores em inglês; strings PT no l10n.
- Padrão de módulo existente: `features/auth/di/auth_module.dart`; padrão de feature com streams: `features/home/*`.

---

## Fase 0 — Infraestrutura de núcleo (`core/`)

**0.1 Config / `.env`** (novo pacote `flutter_dotenv`)
- Criar `mobile/.env` (gitignore) e `mobile/.env.example` (commitado) com:
  `BACKEND_BASE_URL` (ex.: `http://localhost:8000`), `GOOGLE_MAPS_API_KEY`,
  `SUPABASE_URL`, `SUPABASE_KEY`, `ELEVENLABS_*` (já usados), placeholders FCM se faltarem.
- `core/config/app_config.dart`: lê o `.env`, expõe getters tipados (ex.: `apiBaseUrl => '$base/api/v1'`).
- Adicionar `.env` ao `assets:` do `pubspec.yaml` e ao `.gitignore`.
- Nota dev: em device físico `localhost` não resolve → usar IP da máquina no `.env`; Android cleartext
  HTTP em dev exige `android:usesCleartextTraffic="true"` (ou network-security-config) no Manifest.

**0.2 Rede (`core/network/`)** — base para todas as features data layer
- `api_client.dart`: `Dio` com `baseUrl = AppConfig.apiBaseUrl`.
- `auth_interceptor.dart`: injeta `Authorization: Bearer <token>`; em `401 TOKEN_EXPIRED` chama
  `POST /auth/refresh` 1x e repete a request; se refresh falhar → limpa sessão e redireciona a `/login`.
- `error_mapper.dart`: converte `DioException` → `AppFailure` lendo `error.code` (mapeando
  `CONSENT_REQUIRED`, `APPROVAL_REQUIRED`, `FORBIDDEN`, `NOT_FOUND`, `CONFLICT`, `SCORING_UNAVAILABLE`, …).
  Acrescentar variantes em `AppFailure` se necessário (ex.: `consentRequired`, `conflict`).

**0.3 Sessão (`core/session/`)**
- `token_store.dart`: persiste `accessToken`/`refreshToken`/`role`/`homeId` em `flutter_secure_storage`
  (novo pacote) — substitui a dependência de `FirebaseAuth.currentUser`.
- `auth_session.dart`: singleton que guarda token+role em memória e notifica mudanças (usado pelo router).

**0.4 Router (`core/router/app_router.dart`)** — reescrever o `redirect`
- Guard baseado em `AuthSession` (não mais Firebase): sem token → `/login`.
- **Roteamento por papel**: após login, `role == paciente` → `/voice`; `cuidadora`/`profissional` → `/dashboard`.
- **Gate LGPD**: se consentimento ainda não aceito → `/consent` antes de qualquer rota de dados.
- Novas rotas (constantes em `app_routes.dart`): `/consent`, `/select-profile`, `/onboarding`,
  `/dashboard`, `/wellbeing`, `/carechain`, `/orders/:id`, `/map/:orderId`, `/wearable`, `/medications`.
  Deep link de push abre `/orders/:id` ou alerta.

**0.5 Theme / a11y tokens (`core/theme/`)**
- Adicionar `app_dimensions.dart` (espaçamentos, alvo de toque ≥48dp, mic ≥160dp).
- Garantir escalas tipográficas do Paciente (corpo ≥18sp, título ≥32sp) e contraste ≥4.5:1.

**0.6 Shared widgets (`shared/widgets/`)** — reuso ≥70% (spec 07)
- `SeverityChip(level)`, `ExplainableRecommendationCard(product, reason, factors[], weights[], stage, onApprove)`,
  `OrderStageTracker(stage)`, `MapPanel(home, node, route, technician)`, `BigMicButton(state, onTap)`
  (extrair do `home_body.dart` atual), `KeyboardFallbackBar(actions[])` (RN-008),
  `WellbeingDimensionRow(dimensions[])`. `KpiCard` fica para a fase web.
- Estados padrão reutilizáveis: `LoadingSkeleton`, `EmptyState`, `ErrorRetry` (cobrir UI-08).

---

## Fase 1 — Auth (aura-server JWT) + Consentimento LGPD

**1.1 Refatorar feature `auth`** (`features/auth/`)
- `AuthRemoteDataSourceImpl`: trocar Firebase pelo `ApiClient`:
  `POST /auth/signup {email,password,role}`, `POST /auth/login`, `POST /auth/refresh`, `GET /auth/me`.
- Persistir `token/refreshToken/role` via `TokenStore`; popular `AuthSession`.
- `UserModel`/`UserEntity`: campos `userId`, `role` (enum `paciente/cuidadora/profissional/admin`), `name?`.
- `auth_module.dart`: remover `FirebaseAuth.instance`; injetar `ApiClient` + `TokenStore`.
- **Signup** passa a permitir escolher papel (default `cuidadora`).
- Logout limpa `TokenStore`+`AuthSession`.

**1.2 Nova feature `consent`** (`features/consent/`)
- Tela com a Política (texto) + botão "Aceitar"; `POST /consent {version}` → guarda `acceptedAt`.
- Bloqueia avanço até aceite (RN-001). `GET /auth/me`/estado local define se já aceitou.

**1.3 `profile_selection`** (leve)
- Em geral o papel vem do `/auth/login`; tela `/select-profile` só como fallback/atalho de demo
  para alternar Paciente↔Familiar. Roteamento real é por `role`.

---

## Fase 2 — Onboarding da casa + Dashboard + Monitoramento 360 (cuidadora)

**2.1 Feature `home_setup` (onboarding)** (`features/home_setup/`)
- `POST /homes {patientName, birthDate?, cep, label?}` → `{homeId, address, lat, lng}` (ViaCEP no backend).
- `PUT /homes/{id}/checklist {items:{grab_bar_bathroom, slippery_floor, night_light, gas_detector, air_purifier}}`.
- `GET /homes/{id}` para reexibir/editar. Guarda `homeId` ativo em `AuthSession`/`TokenStore`.
- Wizard: dados do paciente → CEP → checklist de segurança (cada item marcado/desmarcado).

**2.2 Feature `caregiver_dashboard`** (`features/caregiver_dashboard/`)
- "Status do dia": maior risco atual (`GET /homes/{id}/scores`), pedidos em aberto
  (`GET /homes/{id}/orders`), atalhos para 360 / Care-Chain / Medicamentos.
- Reusa `SeverityChip`, `OrderStageTracker`.

**2.3 Feature `wellbeing360`** (`features/wellbeing360/`)
- `GET /homes/{id}/scores` (último por dimensão: mobility/sleep/cognition/environment) →
  `WellbeingDimensionRow` + `SeverityChip(level)`.
- `GET /homes/{id}/signals?type=&from=&to=` para histórico/detalhe.
- Botão "recalcular": `POST /scores/recompute {homeId, dimension?}`.
- Integra dados do **wearable** (Fase 4) com selo **"bem-estar, não diagnóstico"** (UI-07).

---

## Fase 3 — Care-Chain (escore explicável → recomendação → pedido)

**3.1 Feature `carechain`** (`features/carechain/`) — o coração do produto
- `POST /scores/recompute` → score + `factors[]`/`weights[]` (paralelos) + `explanation` + `level`.
- `GET /catalog?riskTag=` e `GET /catalog/{sku}`.
- `POST /recommendations {homeId, scoreId}` → recomendação explicável.
- **`ExplainableRecommendationCard`**: SEMPRE mostra produto + preço + **motivo + fatores/pesos + NBR 9050**
  + `OrderStageTracker` + botão "Aprovar e pedir" (UI-03, UI-10).
- `POST /recommendations/{id}/approve` → cria pedido (RN-022). **Sem aprovar, nenhum pedido** (UI-04).
  Tratar `409 CONFLICT` (já aprovada) e `422 APPROVAL_REQUIRED`.

**3.2 Feature `orders` (rastreamento)** (`features/orders/`)
- `GET /homes/{id}/orders` (lista), `GET /orders/{id}` (detalhe: `sla`, `delivery.route/eta`, `installation`).
- `POST /orders/{id}/advance` (avança estágio; em demo pode ser botão admin/simulado).
- `OrderStageTracker(stage)`: `approved→sourcing→in_route→delivered→installed→returned`.

---

## Fase 4 — Conectividade: Mapa + Wearable + Push

**4.1 Feature `delivery_map`** (`features/delivery_map/`)
- `google_maps_flutter` + `geolocator`. `MapPanel`: marcadores casa/nó/entrega/técnico + rota
  (`delivery.route` GeoJSON LineString) + ETA (`delivery.eta`) de `GET /orders/{id}` (UI-05).
- **Permissão de localização**: pedir acesso sem quebrar se negado (UI-06).
- Chave em `GOOGLE_MAPS_API_KEY` (.env) + configurar no Manifest/Info.plist (placeholder se faltar).

**4.2 Feature `wearable`** (`features/wearable/`)
- Pacote `health` (Health Connect/HealthKit), **opt-in**. Ler passos/FC repouso/sono →
  `POST /signals {type:"vitals", source:"wearable", value:{…}}`.
- Permissões no Manifest/Info.plist. Selo "bem-estar, não diagnóstico" (guardrail).

**4.3 Feature `notifications` (FCM)** (`features/notifications/`)
- `firebase_messaging` (usa `firebase_core` já presente). No login: `POST /notifications/register-token {fcmToken}`.
- Foreground/background handlers; **deep link** abre `/orders/:id` (logística) ou alerta (saúde).
- `POST /notifications/test {homeId, kind}` para validar na demo. APNs/google-services como placeholder se faltarem.

---

## Fase 5 — Medicamentos (cuidadora) + Polimento a11y

**5.1 Feature `medications`** (`features/medications/`) — **sem backend hoje**
- CRUD local via **Drift** (`MedicationsTable`) + lembretes locais; UI da cuidadora.
- **Gerar doc** `…/aura-server/docs/PROPOSTA-medications-api.md` propondo as rotas REST
  (`GET/POST/PUT/DELETE /api/v1/homes/{id}/medications`, payloads camelCase) para o backend adicionar depois.
- Desenhar o `MedicationRepository` com contrato já compatível com os endpoints futuros (datasource local
  agora, remoto depois — troca isolada na camada `data`).

**5.2 Polimento WCAG 2.1 AA**
- `Semantics` em todos os controles (TalkBack/VoiceOver); alvos ≥48dp; mic ≥160dp; corpo ≥18sp / título ≥32sp.
- `KeyboardFallbackBar` quando STT indisponível na Home de voz (UI-02, RN-008).
- Skeleton/empty/error/retry em todas as telas (UI-08); responsividade (≤600 telefone, 600–1024 tablet).

**5.3 Limpeza** — `mobile/CLAUDE.md` está desatualizado ("corretores de imóveis"); atualizar a visão geral
para o domínio Aura (mantendo as convenções de arquitetura, que estão corretas).

---

## Arquivos-chave (criar/alterar)

**Criar (representativos):**
- `mobile/.env`, `mobile/.env.example`
- `mobile/lib/core/config/app_config.dart`
- `mobile/lib/core/network/{api_client,auth_interceptor,error_mapper}.dart`
- `mobile/lib/core/session/{token_store,auth_session}.dart`
- `mobile/lib/core/theme/app_dimensions.dart`
- `mobile/lib/shared/widgets/{severity_chip,explainable_recommendation_card,order_stage_tracker,map_panel,big_mic_button,keyboard_fallback_bar,wellbeing_dimension_row}.dart`
- Features novas (cada uma com `data/domain/presentation/di`):
  `consent/`, `home_setup/`, `caregiver_dashboard/`, `wellbeing360/`, `carechain/`, `orders/`,
  `delivery_map/`, `wearable/`, `notifications/`, `medications/`
- `…/aura-server/docs/PROPOSTA-medications-api.md` (doc para o backend)

**Alterar:**
- `mobile/lib/main.dart` (carregar `.env`, init FCM, `AuthSession`; remover dependência de Firebase Auth)
- `mobile/lib/core/router/app_router.dart` + `app_routes.dart` (guard por sessão/papel + gate LGPD + rotas)
- `mobile/lib/core/di/service_locator.dart` (registrar `ApiClient`, `TokenStore` e os novos módulos)
- `mobile/lib/features/auth/**` (Firebase → aura-server JWT)
- `mobile/lib/core/errors/app_failure.dart` (novas variantes de erro de negócio)
- `mobile/lib/features/home/**` (extrair `BigMicButton`; adicionar `KeyboardFallbackBar`)
- `mobile/pubspec.yaml`: add `dio`, `flutter_dotenv`, `flutter_secure_storage`, `google_maps_flutter`,
  `geolocator`, `firebase_messaging`, `health`; manter `supabase_flutter` (token ElevenLabs); remover `firebase_auth`.
- `android/app/src/main/AndroidManifest.xml` + `ios/Runner/Info.plist`: permissões de localização +
  activity recognition (health) + chave Maps + cleartext dev.

---

## Verificação (end-to-end)

1. **Backend local:** subir `aura-server` em `http://localhost:8000`; conferir `GET /health` e o Swagger `/docs`.
   Apontar `BACKEND_BASE_URL` no `.env` (IP da máquina se device físico).
2. **Codegen:** `cd mobile && dart run build_runner build --delete-conflicting-outputs`.
3. **Rodar:** `flutter run`. Validar o **fluxo-herói** ponta a ponta:
   signup/login (cuidadora) → consent → onboarding (CEP + checklist) → registrar `near_fall`
   (via voz/agente ou signal) → recompute (level high) → recomendação explicável → **aprovar** → pedido
   → advance até `in_route` → ver rota+ETA no mapa.
4. **Cenários de aceite (spec 09):** percorrer UI-01..UI-10 — com destaque para
   UI-02 (fallback teclado), UI-03/UI-10 (card sempre mostra fatores/pesos+NBR 9050),
   UI-04 (sem aprovar não há pedido), UI-05/UI-06 (mapa+ETA / permissão negada sem quebrar),
   UI-07 (wearable com selo), UI-08 (loading/empty/error).
5. **Auth/erros:** forçar `401 TOKEN_EXPIRED` (token vencido) e confirmar refresh automático;
   tentar rota de dados sem consentimento → ver gate `CONSENT_REQUIRED`.
6. **Wearable/FCM:** opt-in do `health` envia signal `vitals`; `POST /notifications/test` abre deep link correto.

## Sequência sugerida de execução
Fase 0 → 1 (desbloqueia toda a API) → 2 → 3 (fluxo-herói visível) → 4 → 5. Cada feature só é
"pronta" quando: navega + consome API real + estados loading/empty/error + checklist a11y.
