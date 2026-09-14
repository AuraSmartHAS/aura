# TASK-007 — Implementar ocorrências de medicamentos e confirmação idempotente

## Objetivo e escopo

Trocar confirmações genéricas por ocorrências identificáveis e rotina compartilhada no servidor, com correção explícita de engano. Donos: `backend-java` e `mobile-flutter`; `mobile-react-native` só faz leitura/integração familiar se a task tocar RN, sem ampliar sua fronteira.

## Dependências, contratos e migrações

Depende de `TASK-004`, `TASK-005` e `TASK-006`. O contrato identifica ocorrência agendada e resultado repetível. Migração deve impedir dupla baixa de estoque/adereço e preservar dados existentes conforme análise.

## Aceite

- Toque duplo, timeout e reenvio retornam o mesmo resultado sem segunda confirmação ou baixa.
- Agenda aparece compartilhada; tratamento não é inferido pelo app.
- Correção tem ação explícita e auditoria apropriada.

## Verificação, QA, revisão e continuidade

Runner prova casos idempotentes e reinício. QA verifica fluxo do idoso e leitura familiar. Revisor avalia identidade de ocorrência e consistência banco/contrato. Checkpoint registra migração/evidência; Done após integração e memória.

## Retomada após interrupção

Resolva o checkout canônico em `git worktree list --porcelain`: localize exatamente uma entrada `branch refs/heads/astra-main` e use seu path. Se ausente ou múltipla, escale. Nesse checkout, leia `ROADMAP.md`, `AGENTS.md`, `BLOCKERS.md` e decisões recentes; depois `<astra-main>/journal/TASK-007-CHECKPOINT.md`. Somente ausência nesse caminho significa início. Reconcilie Git, log, diff e status, declare estado/divergências ao orquestrador antes de editar e nunca confie só na conversa. Somente o runner escreve o checkpoint.
