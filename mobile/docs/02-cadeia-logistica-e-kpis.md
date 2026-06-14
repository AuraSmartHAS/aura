# 01 · Cadeia logística e KPIs

Modelo **omnichannel ship-from-store** (simulado): pedido atendido pelo **nó logístico mais próximo** da casa.
`Sinal no app → Torre de Controle → nó mais próximo → last-mile → instalação → reversa`

## Os 8 elos
| Elo | Etapa | KPI |
|---|---|---|
| 1 | Demand sensing (explicável) | acurácia da recomendação |
| 2 | Sourcing/Catálogo (simulado) | fill rate |
| 3 | Estoque (kit da casa + nó) | ruptura |
| 4 | Pedido (cuidadora aprova — RN-022) | conversão recomendação→pedido |
| 5 | Micro-fulfillment (ship-from-store) | lead time de separação |
| 6 | Last-mile (rota + ETA no mapa) | **OTIF / % no SLA** |
| 7 | Instalação (técnico, modelado) | lead time de instalação |
| 8 | Logística reversa (realimenta elo 1) | taxa de reversa/reuso |

## SLAs
item crítico de segurança ≤ 24 h · instalação ≤ 72 h · alerta de saúde ≤ 10 s.

## KPIs (alimentam a Torre de Controle e a validação)
OTIF, fill rate, MAPE (erro da previsão), lead time, cost-to-serve, % instalação no prazo, taxa de reversa.

## Catálogo (produtos de acessibilidade, base NBR 9050 — seeds)
`Kit Barra de Apoio 60cm (queda_banheiro, instalável)` · `Cadeira de Banho (mobilidade)` · `Piso Antiderrapante (queda_banheiro, instalável)` · `Iluminação Noturna c/ Sensor (idas_noturnas)`.
