# Começar ou retomar uma sessão

Abra a **raiz deste repositório** no Codex ou Claude Code. Uma conversa criada fora dela pode não carregar `.codex/` ou `.claude/` automaticamente.

Use este prompt copiável:

```text
Estou retomando o Aura. Execute `git worktree list --porcelain`, encontre exatamente uma entrada `branch refs/heads/astra-main` e use seu path como checkout canônico; se faltar ou houver mais de uma, escale sem adivinhar. Nele, leia nesta ordem: ROADMAP.md, AGENTS.md, BLOCKERS.md, as entradas recentes de DECISIONS.md, o checkpoint da única task `[-]` em `<astra-main>/journal/` e o histórico Git real. Declare o estado encontrado e divergências antes de agir. TODO nunca autoriza execução; uma task só fica `[-]` após autorização registrada pelo runner. Siga AGENTS.md.
```

Para localizar a raiz em qualquer shell, use `git rev-parse --show-toplevel`; use UTF-8 e paths relativos a ela. Antes de criar um worktree, confirme a branch e o diretório comum pelo Git em vez de inferir paths de uma sessão anterior.

Leia `tasks/TASK-NNN-*.md` e somente o checkpoint em `<astra-main>/journal/TASK-NNN-CHECKPOINT.md` para a task `[-]`; nunca use journal da worktree. Ausência nesse checkout canônico significa início. `TASK-001+` permanece pausada até ordem humana expressa.
