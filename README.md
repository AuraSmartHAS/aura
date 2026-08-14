# 📱 AURA Care-Chain — App (Flutter)

> Smart HAS · Enterprise Challenge 2026 (mentoria Leroy Merlin) · **FIAP**
> Assistente de saúde domiciliar **voice-first** para idosos com Parkinson +
> **cadeia logística de segurança da casa**, com recomendação sempre explicada.
> Duas personas, duas superfícies: **Maria** (paciente, fala com o app) e
> **Ana** (cuidadora, acompanha tudo pelo painel).

O código do app vive em [`mobile/`](mobile/) — Flutter para **Android, iOS e Web**.
O backend fica em outro repositório: [aura-server](https://github.com/AuraSmartHAS/aura-server)
(FastAPI + PostgreSQL).

## ⛔ Regras de ouro (nunca violar)
1. **Nunca prescreve/diagnostica** — não é dispositivo médico; sintoma relevante é sempre encaminhado ao médico.
2. **Sem sensores IoT** — o monitoramento vem do próprio app + wearable leve (Health Connect / HealthKit).
3. **Acessibilidade WCAG 2.1 AA, voice-first** — microfone gigante, texto grande, alvos ≥48dp e fallback de teclado sempre disponível.
4. **LGPD desde o desenho** — gate de consentimento antes de qualquer dado de saúde, JWT em storage seguro, exclusão pelo servidor.

---

## 🗺️ Telas e fluxos

### Maria — paciente (voz)
| Rota | O que acontece |
|---|---|
| `/voice` | **Home de voz (VUI)**: microfone gigante, transcrição ao vivo e fallback de teclado. É por conversa que Maria registra **sintomas**, confirma a **medicação** do dia e pede **ajuda/emergência** — o agente de voz (ElevenLabs) conversa e o app registra no servidor. |

### Ana — cuidadora (painel)
| Rota | Feature | O que acontece |
|---|---|---|
| `/onboarding` | `home_setup` | Cadastro da casa (CEP via servidor) + checklist de segurança |
| `/dashboard` | `caregiver_dashboard` | Status do dia da Maria num olhar |
| `/wellbeing` | `wellbeing360` | **Bem-estar 360**: sinais de saúde e humor ao longo do tempo |
| `/carechain` | `carechain` | **Care-Chain**: card de recomendação com risco + fatores + motivo sempre visíveis, e o botão de aprovar — única porta do pedido |
| `/orders/:id` | `orders` | Detalhe e linha do tempo do pedido |
| `/map/:orderId` | `delivery_map` | **Mapa da entrega** (Google Maps) com ETA |
| `/medications` | `medications` | CRUD de medicamentos + lembretes (notificações locais) |
| `/wearable` | `wearable` | Conectar o wearable e sincronizar sinais |

Ana também recebe **push (FCM)** de saúde e de pedido — o token é registrado no servidor no login.

### Compartilhadas
| Rota | O que acontece |
|---|---|
| `/login` · `/signup` | Entrar / criar conta — no cadastro escolhe-se o papel (paciente ou cuidadora), e o roteador leva cada uma para sua casa (`/voice` ou `/dashboard`) |
| `/consent` | **Consentimento LGPD** — obrigatório antes de qualquer tela com dado de saúde |
| `/credits` | Créditos da equipe |

---

## 🧱 Arquitetura do app

```
UI (pages/widgets) ──> BLoC (por feature) ──> UseCases ──> Repositories
                                                              │
                              ┌───────────────────────────────┤
                              │ dio + JWT ──> aura-server /api/v1
                              │ drift ─────> banco local (SQLite)
                              │ health ────> wearable (HC/HealthKit)
                              │ FCM ───────> push  ·  Supabase ──> só o token de voz ElevenLabs
```

- **BLoC por feature**, cada uma com camadas `data / domain / presentation` (Clean Architecture).
- **go_router** com guards de sessão: sem login → `/login`; sem consentimento → `/consent`; depois, rota por papel.
- **get_it** para injeção de dependência (um módulo `di/` por feature).
- **drift** como banco local; **dio + flutter_secure_storage** para falar com o aura-server via JWT.
- **firebase_messaging** só para push; **Supabase** só para buscar o token efêmero do agente de voz — todo o resto passa pelo aura-server.

---

## 🚀 Como rodar

**1. Suba o backend** (repo [aura-server](https://github.com/AuraSmartHAS/aura-server)):
```bash
docker compose up --build
# Swagger em http://localhost:8000/docs
```

**2. Configure o app:**
```bash
cd mobile
cp .env.example .env   # preencha as chaves (o .env fica fora do git)
```
> Em device físico, troque `localhost` pelo IP da sua máquina no `BACKEND_BASE_URL`.

**3. Instale as dependências:**
```bash
flutter pub get
```

**4. Rode:**
```bash
flutter run -d chrome     # web
flutter build web         # build web
flutter build apk         # build Android
```
> Mexeu em modelos drift/freezed? `dart run build_runner build` regenera o código.

---

## 📁 Estrutura

```
mobile/
  lib/
    core/        config · database (drift) · di (get_it) · network (dio+JWT)
                 notifications (FCM + locais) · router (guards) · session · theme
    features/    auth · consent · home (VUI) · home_setup · caregiver_dashboard
                 wellbeing360 · carechain · orders · delivery_map · medications
                 wearable · profile   — cada uma com data/domain/presentation
    shared/      models e widgets reutilizáveis
  docs/          specs 00–10 (produto, telas, a11y, integrações)
  android/ ios/ web/
```

---

## 👥 Equipe

| Nome | RM | Papel |
|---|---|---|
| Vinícius Miranda Baptista | 555081 | Tech Lead |
| João Domingos Góes Filho | 564465 | Dev Senior Mobile |
| Pedro Henrique Arenas Negri | 554971 | Dev Pleno |
| Júlia Alves Dias | 557151 | Infra |

## 🔗 Links
- **Backend:** [github.com/AuraSmartHAS/aura-server](https://github.com/AuraSmartHAS/aura-server)
- **Figma:** [AURA — design](https://www.figma.com/design/vEyinUEawJndUsIAMlJJGc/AURA)
