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

## D-007 — 2026-09-15 — Estratégia de persistência e configuração de rede da TASK-002

- **Decisão:** Flyway (não Liquibase) com `V1` de baseline do schema atual; o perfil `dev`/H2 continua padrão para a suíte existente e o perfil `postgres` passa a ser o do ensaio, com `ddl-auto: validate`; um teste de fumaça com Testcontainers exercita Flyway, boot, seed e reinício em PostgreSQL real; o `DataSeeder` permanece idempotente no boot; a configuração segura desta task cobre apenas o mínimo exigido pela rede local.
- **Evidência:** o perfil `postgres` já existia em `backend-spring/src/main/resources/application.yml` e o H2 já rodava em `MODE=PostgreSQL`; `HomeMemberRole.java:15-21` documentava, pelo próprio time, o risco de `ddl-auto: update` sem migração versionada; `DataSeeder.java:111-113` já condicionava o seed a tabela vazia. Três escalações de arquitetura, privacidade e produto foram respondidas expressamente pelo usuário.
- **Motivo:** a lacuna real não era o PostgreSQL, que já estava montado, e sim schema versionado mais cobertura no banco do ensaio. Manter o H2 como padrão preserva o ciclo rápido de testes; `validate` mais Flyway fecha a bomba-relógio que o time já havia documentado.
- **Descartado:** Liquibase; trocar o perfil padrão para `postgres` em toda a suíte; ligar PostgreSQL sem cobertura de teste; converter o seed em migração versionada; script de seed manual fora do boot; hardening completo com TLS e rotação de segredo, fora da janela de 14 dias.
- **Escolhas conscientes, revistas e mantidas pelo usuário:** `aura.cors.allowed-origins` cobre também `10.*.*.*` e `172.16.*.*`, faixas privadas além da provável, porque nenhuma delas alcança a internet; `spring.flyway.baseline-on-migrate` fica ligado para adotar bancos locais que já nasceram do `ddl-auto: update` anterior.
- **Sem foreign key, deliberadamente:** as entidades guardam UUID solto e não `@ManyToOne`, então o Hibernate nunca gerou FK e `validate` não as exige. Criar FK agora quebraria a exclusão de casa (D-006) sem um `ON DELETE` pensado caso a caso. Há índice nas colunas que a demonstração consulta e o motivo está comentado em `V1__baseline.sql`.

## D-008 — 2026-09-15 — Logística sai; a Leroy passa a ser parceira entre fornecedores

- **Decisão:** remover o controle de entrega do produto e substituí-lo por catálogo multi-fornecedor, página "seja um parceiro" e redirecionamento para o site do parceiro, com o Leroy Merlin Empresas como primeiro caso. A TASK-010 deixa de ser "logística ao operador" e passa a ser a página de parceiro.
- **Evidência:** 3ª Mentoria Enterprise Challenge, 01/09/2026. Guilherme (Leroy) apontou marketplace e classificou o caminho de lead qualificado como mais factível que integração sistêmica; Thatiany (Leroy) enxergou a Leroy como parceira entre fornecedores em B2B e indicou o Leroy Merlin Empresas como caminho mais simples que API; ela também corrigiu um dado do próprio grupo — as lojas são o centro de distribuição da Leroy, e o único CD é Cajamar. Vinicius assumiu o compromisso na reunião e reafirmou internamente.
- **Motivo:** rastrear entrega de terceiro não é o que a plataforma resolve nem controla, e apresentá-lo como integrado seria afirmar capacidade inexistente. A AI Logistics Extension exigida pela Atividade 4 permanece intacta: ela é a cadeia demanda → previsão de ruptura → reposição puxada por consumo → roteamento para a loja mais próxima, e nunca foi o rastreio do caminhão.
- **Reverte:** apenas a parte logística da D-006. O restante da D-006 continua valendo: dono da casa e ADMIN podem excluir casa; provisionamento de ADMIN segue restrito e fora do cadastro público. O código de autorização entregue na TASK-001 não é revertido.
- **Descartado:** manter a esteira de entrega e apenas somar marketplace por cima; esconder a logística da interface mantendo o backend, o que deixaria código sem dono que a auditoria de prontidão encontraria.

## D-009 — 2026-09-15 — Protocolo afrouxado até a gravação do vídeo

- **Decisão:** até a entrega da Atividade 4, o ciclo de oito handoffs de agente por task é substituído por: o orquestrador implementa e roda as provas diretamente, apresenta o diff ao usuário, o usuário revisa e aprova, e um único agente executa o commit. Depois da gravação, o ciclo completo do AGENTS.md volta a valer.
- **Evidência:** medição nesta sessão — cerca de 30 minutos de trabalho contra cerca de 45 minutos de cerimônia e travas. O ambiente aceita um agente por vez; o `runner` ficou 12 minutos sem escrever e o primeiro revisor 16 minutos sem responder. Encerrar agente travado por `TaskStop` ou `tmux kill-pane` derrubava a sessão principal do usuário, duas vezes.
- **Motivo:** o que o protocolo protege de fato — prova de execução e olhar independente sobre o diff — é preservado: os testes continuam sendo rodados e registrados, e o usuário assume o papel de revisor independente. O que sai é o custo de despachar agente para cada passo, num ambiente onde isso é lento e instável, com a banca a poucos dias.
- **Descartado:** manter o ciclo completo e gastar a janela até a banca em cerimônia; commitar sem revisão nenhuma.
