# TASK-009 — Implementar recomendações explicáveis e catálogo Leroy verificável

## Objetivo e escopo

Corrigir checklist e recomendação para explicar origem, priorizar necessidade e oferecer alternativa sem compra; catalogar links oficiais Leroy com fonte/data. Donos: `backend-java`, `mobile-react-native` e `web-frontend` em escopos declarados.

## Dependências, contratos e migrações

Depende de `TASK-001` e `TASK-004`. Checklist aceita sim/não/não sei; telas de consulta não escrevem dados. Catálogo inclui URL oficial, fonte e atualização quando disponíveis; qualquer migração deve preencher escritor/leitor.

## Aceite

- Desconhecido pede esclarecimento, não vira ausência.
- Recomendação mostra relato/condição, data, restrições, ação sem compra e opções aceitar/adiar/recusar/já resolvemos.
- Link abre produto oficial sem afirmar preço, estoque, reserva, pagamento ou rastreio.

## Verificação, QA, revisão e continuidade

Runner executa testes e valida links definidos pela task. QA percorre decisão e retorno. Revisor verifica efeitos de leitura e alegações comerciais. Checkpoint registra fonte/data; Done após integração e memória.

## Retomada após interrupção

Resolva o checkout canônico em `git worktree list --porcelain`: localize exatamente uma entrada `branch refs/heads/astra-main` e use seu path. Se ausente ou múltipla, escale. Nesse checkout, leia `ROADMAP.md`, `AGENTS.md`, `BLOCKERS.md` e decisões recentes; depois `<astra-main>/journal/TASK-009-CHECKPOINT.md`. Somente ausência nesse caminho significa início. Reconcilie Git, log, diff e status, declare estado/divergências ao orquestrador antes de editar e nunca confie só na conversa. Somente o runner escreve o checkpoint.
