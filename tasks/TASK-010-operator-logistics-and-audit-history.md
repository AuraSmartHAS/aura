# TASK-010 — Restringir a logística ao operador e registrar histórico auditável

## Objetivo e escopo

Modelar separar/despachar/entregar/instalar como ações explícitas de operador, com devolução e cancelamento em ramos próprios. Donos: `backend-java` e `web-frontend`; familiar consulta/decide, não movimenta logística.

## Dependências, contratos e migrações

Depende de `TASK-001` e `TASK-009`. Contrato retorna ações permitidas, versão esperada e autor/hora do histórico; instalação é opcional. Migrar sem permitir `instalado → devolvido` como avanço normal.

## Aceite

- Somente operador autorizado altera ações logísticas.
- Conflito concorrente não sobrescreve estado silenciosamente.
- Pedido demonstração identifica `academic_demo`; conclusão de adaptação requer confirmação familiar adequada.

## Verificação, QA, revisão e continuidade

Runner prova transições e concorrência. QA valida painel Angular e visão familiar. Revisor avalia autorização, máquina de estados e auditoria. Checkpoint registra matriz de estados; Done após integração e memória.

## Retomada após interrupção

Resolva o checkout canônico em `git worktree list --porcelain`: localize exatamente uma entrada `branch refs/heads/astra-main` e use seu path. Se ausente ou múltipla, escale. Nesse checkout, leia `ROADMAP.md`, `AGENTS.md`, `BLOCKERS.md` e decisões recentes; depois `<astra-main>/journal/TASK-010-CHECKPOINT.md`. Somente ausência nesse caminho significa início. Reconcilie Git, log, diff e status, declare estado/divergências ao orquestrador antes de editar e nunca confie só na conversa. Somente o runner escreve o checkpoint.
