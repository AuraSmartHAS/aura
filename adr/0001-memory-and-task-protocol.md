# ADR 0001: Memória versionada e protocolo de tasks

- **Data:** 2026-09-14
- **Status:** Aceito

## Contexto

O projeto será longo, pode perder sessões e pode ser executado por harnesses diferentes. A memória conversacional e worktrees não integradas não são persistência suficiente.

## Decisão

Manter roadmap, tasks, checkpoints, decisões e ADRs versionados. `astra-main`, resolvida por entrada única no `git worktree list --porcelain`, é a integração canônica; exatamente uma task `[-]` está ativa. Runner é único escritor de checkpoint e de estados runtime do roadmap, e VCS é único agente Git mutante. O encerramento tem commit de memória separado após squash/push verificados.

## Consequências

Retomadas reconciliam documentos com Git real. Há custo deliberado de checkpoint, verificação, revisão e commit de encerramento. Snapshots materializados/versionados em worktrees podem existir, mas não são canônicos nem são lidos/alterados; o único journal canônico fica no checkout resolvido de `astra-main`. Não são permitidos commit WIP/não revisado, stash/clean automático ou marcação Done sem evidência. Antes de revisão, a resiliência vem do checkpoint canônico, não de Git.

## Alternativas descartadas

Memória apenas no chat, checklist sem Git, checkpoint por implementador e múltiplas integrações paralelas sem dono único.
