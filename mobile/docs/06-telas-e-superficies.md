# 06 · Telas e superfícies

## As 4 superfícies
| Superfície | Quem | Plataforma | Essência |
|---|---|---|---|
| Mobile · Paciente (Maria) | idoso | celular | VUI voice-first |
| Mobile · Familiar (Ana) | cuidador(a) | celular | dashboard |
| Web · Pessoa | família/cuidadora/profissional | navegador | portal de acompanhamento + relatórios |
| Web · Admin | operação/coordenação | navegador | Torre de Controle (KPIs, fila, alertas) |

## Telas mobile — Paciente (VUI)
Login+LGPD · **Home de voz** (microfone gigante, transcrição ao vivo, **fallback de teclado** RN-008) · Registrar sintoma (voz) · Lembrete de medicamento (confirmar por voz) · **Emergência** (confirmação verbal RN-004) · Check-in de bem-estar.

## Telas mobile — Familiar (dashboard)
Dashboard (status do dia) · CRUD de medicamentos · **Painel 360** (chips de severidade) · **Care-Chain** (card explicável + aprovar) · Acompanhamento de pedido · **Mapa** · Conectar wearable · Histórico.

## Telas web — Pessoa (portal)
Visão geral do paciente · Painel 360 (gráficos no tempo) · Care-Chain (aprovar/acompanhar) · **Relatórios (export PDF/CSV)** · Config & consentimento.

## Telas web — Admin (Torre de Controle)
Login+RBAC · Visão geral (KPIs) · Painel 360 (lista) · **Fila logística (kanban + SLA)** · Mapa operacional · Alertas & escalonamento · Catálogo & regras · Auditoria & LGPD.

## Wireframes-chave (texto)
**Home de voz (Maria):** título 32sp + instrução + **microfone ≥160dp** + transcrição (auto-scroll) + barra de fallback (botões ≥48dp). Estados: ocioso/ouvindo/transcrevendo/erro.
**Card de recomendação explicável (a alma):**
```
[Risco ALTO] Kit Barra de Apoio 60cm — R$129,90
Porque: 2 quase-quedas/14d + banheiro sem barra (NBR 9050)   ← SEMPRE visível
●Pedido ○Separação ○Rota ○Entregue ○Instalado
[ Aprovar e pedir ]   ← única porta do pedido (RN-022)
```
**Admin (desktop):** sidebar + conteúdo; cartões de KPI no topo; kanban de pedidos; <1024px o menu recolhe.
