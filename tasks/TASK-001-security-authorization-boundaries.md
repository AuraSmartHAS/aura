# TASK-001 — Corrigir fronteiras de autorização e privilégios

## Objetivo e escopo

Impedir cadastro público de operador/admin, limitar operações destrutivas ao papel adequado e bloquear transições de logística por idoso/familiar também na API. Dono: `backend-java`; `analista` mapeia pontos afetados.

## Dependências, contratos e migrações

Depende de `TASK-000`. Preserva `/api/v1`, mas ajusta regras de autorização e respostas de negação. Não introduzir campos opcionais para contornar autorização; avaliar migração somente se o papel persistido exigir ajuste explícito.

## Aceite

- Cliente não escolhe papel privilegiado no cadastro público.
- Membro de casa sem permissão não apaga casa nem altera logística, inclusive por chamada direta.
- Testes negativos provam isolamento de família e permissões por papel.

## Verificação, QA, revisão e continuidade

Runner executa a suíte Spring e coleta exit code/log. `qa-tests` verifica fluxos visíveis se houver tela afetada. Revisor independente aprova cada fatia antes do commit. Runner checkpointa evidência, arquivos e próximo passo; retomar pelo journal e Git real. Done exige squash/push e commit de memória.

## Retomada após interrupção

Resolva o checkout canônico em `git worktree list --porcelain`: localize exatamente uma entrada `branch refs/heads/astra-main` e use seu path. Se ausente ou múltipla, escale. Nesse checkout, leia `ROADMAP.md`, `AGENTS.md`, `BLOCKERS.md` e decisões recentes; depois `<astra-main>/journal/TASK-001-CHECKPOINT.md`. Somente ausência nesse caminho significa início. Reconcilie Git, log, diff e status, declare estado/divergências ao orquestrador antes de editar e nunca confie só na conversa. Somente o runner escreve o checkpoint.
