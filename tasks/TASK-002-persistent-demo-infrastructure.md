# TASK-002 — Tornar a infraestrutura da demonstração persistente e acessível na rede local

## Objetivo e escopo

Preparar Spring com PostgreSQL persistente, migrações versionadas e configuração segura para notebook/celulares na rede local. Donos: `backend-java` e `runner` para prova operacional. Não hospedar publicamente.

## Dependências, contratos e migrações

Depende de `TASK-001`. Substitui a continuidade efêmera de H2 no cenário demonstrado; documenta configuração sem segredos e sem inventar infraestrutura paga. A migração deve preservar leitores e escritores existentes.

## Aceite

- Reinício do backend preserva dados de demonstração criados durante o ensaio.
- Androids na rede configurada alcançam a API do notebook.
- Nenhuma configuração de demonstração afirma disponibilidade quando o notebook está desligado.

## Verificação, QA, revisão e continuidade

Runner executa migrações, inicialização e reinício com timestamps/exit codes. `qa-tests` confirma acesso no dispositivo quando habilitado. Revisor avalia configuração e dados. Checkpoint registra ambiente, evidência e bloqueios de rede; Done exige ciclo completo de integração e memória.

## Retomada após interrupção

Resolva o checkout canônico em `git worktree list --porcelain`: localize exatamente uma entrada `branch refs/heads/astra-main` e use seu path. Se ausente ou múltipla, escale. Nesse checkout, leia `ROADMAP.md`, `AGENTS.md`, `BLOCKERS.md` e decisões recentes; depois `<astra-main>/journal/TASK-002-CHECKPOINT.md`. Somente ausência nesse caminho significa início. Reconcilie Git, log, diff e status, declare estado/divergências ao orquestrador antes de editar e nunca confie só na conversa. Somente o runner escreve o checkpoint.
