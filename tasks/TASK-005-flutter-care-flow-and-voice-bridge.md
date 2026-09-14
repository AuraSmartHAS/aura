# TASK-005 — Conectar o fluxo Flutter do idoso, texto e voz ao contrato de cuidado

## Objetivo e escopo

Fazer relato textual e por voz registrar eventos reais no Spring, consultar agenda e confirmar ações por ferramentas de cliente. Dono: `mobile-flutter`; `backend-java` somente se o contrato de `TASK-004` exigir implementação já aprovada.

## Dependências, contratos e migrações

Depende de `TASK-004`. Usa token temporário autenticado para conversa ElevenLabs e client tools na LAN; chave permanente não entra no cliente. Não há migração Flutter que substitua o servidor como fonte compartilhada.

## Aceite

- Texto funciona sem iniciar sessão de áudio, inclusive microfone negado ou crédito indisponível.
- Confirmação ao idoso depende da resposta da API, não de fala do modelo.
- Evento mostra estado honesto de conexão e pode ser reenviado sem duplicação.

## Verificação, QA, revisão e continuidade

Runner executa build/testes Flutter e prova em Android quando disponível; QA testa TalkBack, 200% e fallback textual. Revisor não recebe contexto herdado. Checkpoint guarda evidência de contrato e limitações de voz; Done após integração e memória.

## Retomada após interrupção

Resolva o checkout canônico em `git worktree list --porcelain`: localize exatamente uma entrada `branch refs/heads/astra-main` e use seu path. Se ausente ou múltipla, escale. Nesse checkout, leia `ROADMAP.md`, `AGENTS.md`, `BLOCKERS.md` e decisões recentes; depois `<astra-main>/journal/TASK-005-CHECKPOINT.md`. Somente ausência nesse caminho significa início. Reconcilie Git, log, diff e status, declare estado/divergências ao orquestrador antes de editar e nunca confie só na conversa. Somente o runner escreve o checkpoint.
