# 05 · Arquitetura e estado (frontend)

## 1 codebase, múltiplos entrypoints
```
lib/
  main_mobile.dart   # app (Paciente + Familiar)
  main_web.dart      # web (Pessoa + Admin)
  app.dart           # MaterialApp.router + tema
  core/              # theme/design system, router(go_router), di(get_it), network(dio), auth
  shared/            # widgets reutilizáveis (ver 07)
  features/
    auth/ profile_selection/ voice/ medication/ wellbeing360/
    carechain/ delivery_map/ caregiver_dashboard/
    web_portal/        # superfície Web Pessoa
    ops_console/       # superfície Web Admin
    credits/
```
- **Seleção de superfície:** entrypoint (mobile/web) + **papel** (RBAC do backend) + **breakpoint** (≥1024px = layout desktop).
- **Clean Architecture leve por feature:** `data / domain / presentation`.
- **Estado = BLoC:** 1 por feature (`AuthBloc`, `VoiceBloc`, `MedicationBloc`, `Wellbeing360Bloc`, `CareChainBloc`, `OrderTrackingBloc`, `MapBloc`, `WearableBloc`, `OpsBloc`). Estados `initial/loading/ready/error`.

## Fluxo de um BLoC (padrão)
`evento → caso de uso (domain) → repositório (data) → API → novo estado`. Ex.: `LoadRecommendations` → `GET /homes/{id}/scores` + `GET /catalog` → `ready(recommendations)`; `ApproveRecommendation` → `POST /recommendations/{id}/approve` → atualiza estágio.

## Navegação (go_router)
`/login /select-profile /voice /voice/medication /voice/emergency /checkin /dashboard /medications /wellbeing /carechain /orders/:id /map /wearable /credits` · web: `/portal/*` (Pessoa) e `/ops/*` (Admin). Guardas por papel; deep link de push abre `/orders/:id` ou alerta.
