# TASK-008 — Corrigir autorização e estados honestos do SOS

## Objetivo e escopo

Garantir SOS autorizado por dispositivo pareado, cancelável dentro da janela prevista e com estados reais de registro, envio e resposta humana. Donos: `backend-java`, `mobile-flutter` e `mobile-react-native` por seus limites.

## Dependências, contratos e migrações

Depende de `TASK-003`, `TASK-004`, `TASK-005` e `TASK-006`. Consulta/cancelamento exigem vínculo adequado; dispositivo pode ter autorização SOS revogável. Migrar estado somente com escritor/leitor e retenção definida pela task.

## Aceite

- Não membro não dispara, consulta ou cancela SOS de outra família.
- Falha de token/provedor ou ausência de resposta nunca aparece como ajuda confirmada.
- Familiar confirma “vi” e “estou indo”; idoso vê a resposta. Sem rede, há caminho imediato ao contato cadastrado.

## Verificação, QA, revisão e continuidade

Runner simula falhas e prova a janela de cinco segundos. QA testa no dispositivo com contatos da equipe, sem serviços públicos. Revisor prioriza autorização e estados. Checkpoint registra cenário seguro; Done após integração e memória.

## Retomada após interrupção

Resolva o checkout canônico em `git worktree list --porcelain`: localize exatamente uma entrada `branch refs/heads/astra-main` e use seu path. Se ausente ou múltipla, escale. Nesse checkout, leia `ROADMAP.md`, `AGENTS.md`, `BLOCKERS.md` e decisões recentes; depois `<astra-main>/journal/TASK-008-CHECKPOINT.md`. Somente ausência nesse caminho significa início. Reconcilie Git, log, diff e status, declare estado/divergências ao orquestrador antes de editar e nunca confie só na conversa. Somente o runner escreve o checkpoint.
