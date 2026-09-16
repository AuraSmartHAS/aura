# Log de decisões

> Append-only. Toda entrada inclui data, decisão, evidência, motivo e alternativas descartadas. Reversões recebem nova entrada; não reescreva a anterior.

## D-001 — 2026-09-14 — `astra-main` é a linha de integração

- **Decisão:** criar e usar `astra-main`, derivada de `main` atualizada, como base de tasks e memória; `main` permanece intocada até a validação manual final do usuário.
- **Evidência:** o histórico local confirmou `main` e `astra-main` no mesmo commit `19dc1bb1638ab9bec79be81e43cbb4493c3423b2` quando a branch foi criada; não existe upstream neste bootstrap.
- **Motivo:** isola a evolução da competição e preserva o gate final humano.
- **Descartado:** usar `main` diretamente; manter a referência anterior a `astra-revision`.

## D-002 — 2026-09-14 — memória é versionada e canônica no checkout de integração

- **Decisão:** ROADMAP, tasks, journals, decisões, ADRs e configuração de agentes ficam no repositório e a cópia canônica vive no checkout de `astra-main`.
- **Evidência:** a sessão pode sofrer compactação, queda de rede, expiração de crédito e execução por Codex ou Claude Code; havia ausência de todos esses arquivos no inventário inicial.
- **Motivo:** uma retomada precisa ser possível sem memória da conversa ou de uma worktree efêmera.
- **Descartado:** depender do histórico de chat, de notas locais fora do Git ou de cópias por worktree.

## D-003 — 2026-09-14 — papéis separados e custo proporcional à incerteza

- **Decisão:** Terra/Sonnet implementa e executa dentro de fronteiras conhecidas; Sol/Opus investiga e revisa, sem escrever código. Runner e VCS são funções separadas.
- **Evidência:** o pedido do time exige reduzir custo e evitar que quem escreveu valide as próprias suposições.
- **Motivo:** concentra modelos caros em descoberta e julgamento, mantendo evidência e histórico independentes.
- **Descartado:** um agente generalista para implementar, executar, revisar e commitar; reutilizar analista/revisor entre tasks.

## D-004 — 2026-09-14 — foco de competição e limites comerciais

- **Decisão:** o fluxo prioritário é idoso no Flutter → Spring → familiar no React Native → confirmação ao idoso; a demonstração usa PostgreSQL, dois Androids e notebook em rede local. Leroy é link de produto verificado e pedido acadêmico identificado, sem alegar integração transacional.
- **Evidência:** não há credenciais Leroy; o diagnóstico identificou gaps de autorização, vínculo, persistência, eventos, RN e Flutter.
- **Motivo:** entrega verificável em até 14 dias, sem custo novo, CNPJ ou alegações comerciais falsas.
- **Descartado:** depender de API Leroy, tratar FastAPI como backend ativo, lançar mapas/wearable/integração comercial antes do ciclo principal.

## D-005 — 2026-09-14 — versionar a ponte de entrada do Claude Code

- **Decisão:** remover a regra ampla que ignorava `CLAUDE.md`, para versionar a ponte curta que leva integrantes a `START-HERE.md` e `AGENTS.md`.
- **Evidência:** `git check-ignore` identificou a linha 1 de `.gitignore` como responsável por excluir a única ponte, enquanto `.claude/agents/` permanecia incluível.
- **Motivo:** a memória precisa ser compartilhada e versionada; depender de cada membro saber abrir manualmente os documentos canônicos anula a retomada automática no Claude Code.
- **Descartado:** manter a ponte apenas local; depender de conhecimento prévio de cada integrante para abrir `AGENTS.md`.

## D-006 — 2026-09-15 — Políticas de autorização da TASK-001

- **Decisão:** dono da casa e ADMIN podem excluir uma casa; somente o ADMIN existente movimenta logística; implementar provisionamento restrito de contas ADMIN fora do cadastro público.
- **Evidência:** respostas expressas do usuário nesta sessão às três lacunas levantadas pelo analista.
- **Motivo:** fechar as fronteiras de autorização sem atribuir privilégios administrativos ao idoso ou familiar.
- **Descartado:** exclusão por membro comum; novo papel OPERADOR nesta etapa; manter apenas o seed como mecanismo de provisionamento ADMIN.
