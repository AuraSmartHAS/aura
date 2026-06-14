# 07 · Design system e acessibilidade

## Acessibilidade (WCAG 2.1 AA) — obrigatório
- Tipografia: corpo ≥ 18sp, títulos ≥ 32sp (Paciente). Contraste ≥ 4.5:1. Alvo de toque ≥ 48dp.
- **Voice-first:** nenhum fluxo crítico do Paciente exige leitura/toque preciso; **fallback de teclado** sempre (RN-008).
- `Semantics` em todos os controles (TalkBack/VoiceOver).
- Responsivo: ≤600 telefone · 600–1024 tablet · ≥1024 desktop (web = sidebar + conteúdo).

## Componentes compartilhados (em `shared/`, usados pelas 4 superfícies → reuso ≥70%)
| Componente | Props |
|---|---|
| `KpiCard` | label, value, color |
| `SeverityChip` | level (alto/atenção/ok) |
| `ExplainableRecommendationCard` | product, reason, factors[], stage, onApprove |
| `OrderStageTracker` | stage |
| `MapPanel` | home, node, route, technician |
| `BigMicButton` | onTap, listeningState |
| `KeyboardFallbackBar` | actions[] (RN-008) |
| `WellbeingDimensionRow` | patient, dimensions[] |

## Explicabilidade na UI (princípio)
Todo card de recomendação mostra **produto + motivo + fatores/pesos + norma (NBR 9050)** (vindos de `/scores`). Alerta mostra o **gatilho observável**. Nunca "a IA sugeriu" sem o porquê.
