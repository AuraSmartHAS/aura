# TASK-004 — Definir eventos de cuidado, idempotência, outbox e histórico compartilhado

## Objetivo e escopo

Persistir relatos com autoria/horários do servidor, identificador idempotente, processamento por outbox e histórico incremental para notificação e resposta. Dono: `backend-java`; `analista` confirma contratos atuais.

## Dependências, contratos e migrações

Depende de `TASK-003`. Estende `/api/v1` com evento, cursor, leitura e resposta humana; não cria efeito de escrita ao abrir tela. Migrações devem incluir escritor, consumidor e recuperação em reinício.

## Aceite

- Relato é processado uma vez mesmo após reenvio.
- Falha de entrega fica pendente e recuperável; não vira sucesso falso.
- Histórico incremental é isolado por casa e expõe contrato de cursor, leitura e resposta sem efeito de escrita ao consultar.

## Verificação, QA, revisão e continuidade

Runner prova no backend transação, idempotência, outbox, falha/retry, isolamento e reinício. `qa-tests` valida o contrato autenticado e o histórico por cenário controlado nesta task. Revisor verifica transação, autorização e contrato. A validação ponta a ponta pelos clientes pertence a `TASK-005`, `TASK-006` e `TASK-011`, e não bloqueia o Done de `TASK-004`. Checkpoint inclui IDs seguros de cenário, evidência e próxima dependência; Done após integração e memória.

## Retomada após interrupção

Resolva o checkout canônico em `git worktree list --porcelain`: localize exatamente uma entrada `branch refs/heads/astra-main` e use seu path. Se ausente ou múltipla, escale. Nesse checkout, leia `ROADMAP.md`, `AGENTS.md`, `BLOCKERS.md` e decisões recentes; depois `<astra-main>/journal/TASK-004-CHECKPOINT.md`. Somente ausência nesse caminho significa início. Reconcilie Git, log, diff e status, declare estado/divergências ao orquestrador antes de editar e nunca confie só na conversa. Somente o runner escreve o checkpoint.
