# TASK-000 — Bootstrap da memória durável e configuração de papéis

## Objetivo

Versionar a memória de projeto, o protocolo de continuidade e configurações portáveis de agentes, sem implementar produto.

## Escopo e donos

- **Dono documental:** redator de memória; escreve somente os arquivos listados nesta task.
- **Runner:** único escritor de `journal/TASK-000-CHECKPOINT.md`; reconcilia status autorizado.
- **VCS:** único agente Git mutante; commit local somente com mensagem literal do orquestrador.
- **Revisor:** revisa documentação/configuração sem contexto herdado.

Não tocar em fonte, dependências, ambiente, segredos, `mobile/docs/` ou catálogo Word não rastreado.

## Dependências e contratos

Depende da branch `astra-main` criada de `main` atualizada. Cria o contrato operacional definido por `AGENTS.md`, com `astra-main` como memória canônica e uma integração ativa por padrão.

## Migrações

Nenhuma migração de produto ou banco.

## Aceite

- Os arquivos de memória, ADRs, roles e configurações Codex/Claude existem e apontam ao protocolo canônico.
- `TASK-001+` estão pausadas por ordem humana explícita; TODO não dispara trabalho.
- `CLAUDE.md` preserva o trecho histórico como observação e aponta à raiz canônica.
- Não há alteração de fonte, package, build, journal por outro papel, catálogo ou `mobile/docs/`.

## Verificação e QA

Runner executa apenas validações de documentação/configuração autorizadas, incluindo `codex doctor --summary --no-color --ascii` quando disponível. Não instalar Node nem tentar contornar o Node 18 que causa `TypeError` no Claude. Uma sessão nova confirma descoberta por `/agents` quando a harness permitir.

## Revisão, checkpoint e encerramento

Revisor independente examina o diff antes do commit local. O runner atualiza somente o checkpoint. VCS faz commit inicial de memória, runner registra o hash de entrega, revisor examina o delta de encerramento e VCS faz commit local curto de conclusão. Não há push neste bootstrap. Só então marcar `TASK-000` como Done.

## Retomada após interrupção

Resolva o checkout canônico em `git worktree list --porcelain`: localize exatamente uma entrada `branch refs/heads/astra-main` e use seu path. Se ausente ou múltipla, escale. Nesse checkout, leia `ROADMAP.md`, `AGENTS.md`, `BLOCKERS.md` e decisões recentes; depois `<astra-main>/journal/TASK-000-CHECKPOINT.md`. Somente ausência nesse caminho significa início. Reconcilie Git, log, diff e status, declare estado/divergências ao orquestrador antes de editar e nunca confie só na conversa. Somente o runner escreve o checkpoint.
