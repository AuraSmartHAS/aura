# TASK-001 — Corrigir fronteiras de autorização e privilégios

Estado: entrega concluída; memória de encerramento preparada para revisão, commit e push. A única tarefa autorizada nesta sessão foi concluída no código; nenhuma segunda tarefa foi iniciada.

## Autorização e decisão

- Autorização humana: iniciar e concluir a primeira TODO executável; não iniciar uma segunda tarefa nesta sessão.
- D-006 permanece intacta: dono e ADMIN podem excluir casa; ADMIN existente movimenta logística; provisionamento de ADMIN é restrito e fica fora do cadastro público.

## Entrega e integridade Git

- Repositório: `AuraSmartHAS/aura`; checkout canônico: `/Users/arenas/OrcaRepos/AuraSmartHAS/aura`, `astra-main`.
- Base: `67015be22321807f8c5d1f8ce32f260acdec8829`; `pull --ff-only` precedeu a criação da worktree.
- Commit da task: `9bfa74ec807785ea5647062c795463267dd1e066`.
- Entrega squash: `4fcc5133aded6129388650f6d6fe622962f0a32b`; `HEAD` e `origin/astra-main` confirmados nesse mesmo hash após `push -u`.
- Mensagem literal: `fix(security): enforce account and household authorization boundaries`.
- Worktree e branch `task-001/security-authorization-boundaries` foram removidas após o push e antes do marcador `[X]`.
- `main` não foi alterada: `origin/main` permanece `32f44e9bb0b68e5ded3c4fe6d93bbd0cbcd6652a`.

## Alterações entregues

- Cadastro público de ADMIN negado; `POST /api/v1/auth/admins` restrito a ADMIN vigente e sem retorno de tokens.
- Exclusão de casa por dono ou ADMIN; logística exclusiva de ADMIN.
- JWT revalidado contra conta e papel persistidos.
- Contratos públicos e resposta de provisionamento corrigidos.
- Regressões protegem contra conta ADMIN excluída e papel rebaixado.

## Evidências

- Verificação final: 72 testes, 0 falhas, 0 erros, exit `0`; `/tmp/aura-task-001-spring-post-schema-annotation-20260915T204229-0300.log`.
- HTTP: token excluído retorna `401` e candidata no login retorna `401`; `/tmp/aura-task-001-http-after-token-fix-20260915T203608-0300.log`.
- UI: cuidadora `403` sem mudança e ADMIN em `/home` `200`, `Aprovado` para `Separando`; `/tmp/aura-task-001-web-auth-boundaries-after-fix-2026-09-15T20-37-32.log`.
- QA independente `ctx_0296727a80af`: APROVADO.
- Revisor final `ctx_5c1b05ca9c8b` aprovou commit e squash; artefato SHA-256 `4574061c61a33cf33d1957d20e364fdbbfe019f5bb907841407bda14fe185016`; o runner confirmou bytes com `cmp` exit `0` antes do VCS.
- Contrato projetado: baseline apenas nas operações TASK-001, 250 referências resolvidas e igualdade semântica fora da allowlist.

## Limites e histórico relevante

- Limites desta task: H2/seed/MockMvc; PostgreSQL, dois Androids e concorrência de rebaixamento durante request não eram exigidos. Membro não dono foi validado por integração por ausência de endpoint HTTP.
- B-001 Leroy e B-002 rede/voz permanecem para outras tasks.
- A revisão inicial bloqueou token de ADMIN excluído e churn OpenAPI; ambos foram corrigidos e reverificados antes de qualquer commit.
- Não houve nova migração, `Role`, infraestrutura ou alteração de UI.

## Próximo passo autorizado

Revisar, commitar e publicar somente esta memória com a mensagem `docs(task-001): record verified delivery and completion`; depois encerrar todos os agentes, sem iniciar TASK-002. Este checkpoint registra somente o hash de entrega; o hash do commit de memória é obtido no Git e não é autoinscrito.
