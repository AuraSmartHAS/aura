# TASK-012 — Validar a demonstração e preparar a apresentação da banca

## Objetivo e escopo

Ensaiar o fluxo completo com contas novas: parear, relatar, receber/responder, recomendar/linkar Leroy, operar pedido acadêmico e confirmar adaptação. Donos: `qa-tests`, `runner`, `web-frontend`, `mobile-flutter`, `mobile-react-native` e `backend-java` somente para defeitos confirmados.

## Dependências, contratos e migrações

Depende de `TASK-001` a `TASK-011`. Não muda arquitetura por estética de apresentação; qualquer migração é tarefa corretiva explícita. Mede tempo, sucesso, duplicação e recuperação com amostra/condições declaradas.

## Aceite

- Roteiro funciona sem edição manual do banco ou contas seed.
- Demonstração não alega integração comercial, clínica ou de emergência inexistente.
- Falhas conhecidas, alternativa e condição de rede são documentadas.
- Usuário executa o gate manual final antes de qualquer merge em `main`.

## Verificação, QA, revisão e continuidade

Runner produz evidência do ensaio e ambiente; QA registra tarefas e resultados. Revisor avalia apenas correções geradas. Checkpoint contém roteiro/limitações. Done requer squash/push em `astra-main`, encerramento de memória e nenhuma alteração automática em `main`.

## Retomada após interrupção

Resolva o checkout canônico em `git worktree list --porcelain`: localize exatamente uma entrada `branch refs/heads/astra-main` e use seu path. Se ausente ou múltipla, escale. Nesse checkout, leia `ROADMAP.md`, `AGENTS.md`, `BLOCKERS.md` e decisões recentes; depois `<astra-main>/journal/TASK-012-CHECKPOINT.md`. Somente ausência nesse caminho significa início. Reconcilie Git, log, diff e status, declare estado/divergências ao orquestrador antes de editar e nunca confie só na conversa. Somente o runner escreve o checkpoint.
