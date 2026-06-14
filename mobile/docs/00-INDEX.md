# 📱 FRONTEND — Índice das specs (AURA Care-Chain)

> Pacote **autossuficiente** para construir o **frontend Flutter unificado** (responsável: João).
> Para o Claude Code: leia na ordem. Pode renomear este arquivo para `CLAUDE.md` na raiz do repo Flutter.

## ⛔ Regras de ouro (nunca violar)
1. **Nunca prescrever/diagnosticar** na UI — sempre encaminhar ao médico. Medicamento é só sinal.
2. **Sem IoT** — wearable é leitura leve do dispositivo do usuário (pacote `health`).
3. **Tudo explicável** — todo card de recomendação mostra fatores+pesos+motivo+norma.
4. **Estado = BLoC** · navegação **go_router** · DI **get_it**.
5. **Acessibilidade WCAG 2.1 AA** e **voice-first** nos fluxos do paciente (**fallback de teclado** sempre).
6. **1 codebase, 4 superfícies:** mobile Paciente + Familiar; web Pessoa + Admin.
7. **LGPD:** consentimento explícito antes de coletar qualquer dado; exibir a política; respeitar privacidade na UI.

## Índice
| # | Arquivo | Conteúdo |
|---|---|---|
| 01 | `01-visao-produto-e-premissas.md` | produto, personas, fluxo-herói |
| 02 | `02-cadeia-logistica-e-kpis.md` | o que a UI exibe (estágios, KPIs) |
| 03 | `03-monitoramento-360.md` | dimensões + wearable (`health`) |
| 04 | `04-escore-explicavel.md` | o "porquê" a exibir nos cards |
| 05 | `05-arquitetura-e-estado.md` | 1 codebase, flavors, BLoC, router, DI |
| 06 | `06-telas-e-superficies.md` | inventário + specs/wireframes por superfície |
| 07 | `07-design-system-e-a11y.md` | componentes compartilhados + acessibilidade |
| 08 | `08-integracoes-e-api.md` | REST, mapas, FCM, wearable, voz + endpoints consumidos |
| 09 | `09-roadmap-e-aceite.md` | sprints, DoD, cenários Dado/Quando/Então |
| 10 | `10-glossario.md` | termos |

> Detalhe exaustivo: `../PRDs/PRD - Frontend Flutter Unificado (AURA Care-Chain).md`.
