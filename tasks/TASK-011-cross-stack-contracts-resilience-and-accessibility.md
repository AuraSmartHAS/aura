# TASK-011 — Validar contratos, resiliência, acessibilidade e cenários negativos entre stacks

## Objetivo e escopo

Fechar contratos compartilhados e provar recuperação de falha, isolamento, acessibilidade e continuidade. Donos: `qa-tests`, `runner`, `analista` e os implementadores donos da stack afetada para corrigir defeitos confirmados por evidência de QA, runner, analista ou revisor.

## Dependências, contratos e migrações

Depende de `TASK-001` a `TASK-010`. Não inventa produto novo; documenta e testa contratos já aprovados. Migração somente se um teste provar incoerência bilateral e a task corretiva declarar escritor/banco/leitor.

## Aceite

- Reinício preserva registros; reconexão envia pendência uma vez.
- Famílias não se misturam por IDs alterados.
- Flutter essencial passa fonte 200%, TalkBack, contraste, teclado e botões grandes.
- Voz/push/rede falhos preservam estado honesto e alternativas utilizáveis.

## Verificação, QA, revisão e continuidade

Runner reúne execução primária por stack; QA usa Samsung e dois aparelhos. Implementador corrige somente defeito confirmado e cada diff volta a passar por verificação do runner e revisão independente antes de commit. Revisor não se autorrevisa. Checkpoint lista evidências e lacunas; Done após todos os gates aplicáveis e memória.

## Retomada após interrupção

Resolva o checkout canônico em `git worktree list --porcelain`: localize exatamente uma entrada `branch refs/heads/astra-main` e use seu path. Se ausente ou múltipla, escale. Nesse checkout, leia `ROADMAP.md`, `AGENTS.md`, `BLOCKERS.md` e decisões recentes; depois `<astra-main>/journal/TASK-011-CHECKPOINT.md`. Somente ausência nesse caminho significa início. Reconcilie Git, log, diff e status, declare estado/divergências ao orquestrador antes de editar e nunca confie só na conversa. Somente o runner escreve o checkpoint.
