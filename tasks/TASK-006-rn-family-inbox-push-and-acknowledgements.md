# TASK-006 — Construir inbox, push e confirmações do familiar em React Native

## Objetivo e escopo

Entregar sessão persistida, inbox de eventos, consulta incremental, FCM nativo e respostas humanas que retornam ao idoso. Dono: `mobile-react-native`; `backend-java` somente no contrato aprovado.

## Dependências, contratos e migrações

Depende de `TASK-003` e `TASK-004`. Usa token FCM direto compatível com APK de desenvolvimento; não depende de Expo Go. Leitura, push e resposta são operações distintas e não criam recomendação ao abrir tela.

## Aceite

- Familiar novo recebe relato correto, horário/autoria e responde.
- Push aberto, em segundo plano e no encerramento normal abre o evento correto quando suportado; limitações de encerramento forçado Android são registradas.
- Histórico recupera eventos sem duplicação após reconexão.

## Verificação, QA, revisão e continuidade

Runner executa builds/suites e captura evidência FCM. QA usa Samsung. Revisor avalia sessão, token e efeitos de navegação. Checkpoint lista estado e limitações; Done após fluxo Flutter → RN → Flutter, integração e memória.

## Retomada após interrupção

Resolva o checkout canônico em `git worktree list --porcelain`: localize exatamente uma entrada `branch refs/heads/astra-main` e use seu path. Se ausente ou múltipla, escale. Nesse checkout, leia `ROADMAP.md`, `AGENTS.md`, `BLOCKERS.md` e decisões recentes; depois `<astra-main>/journal/TASK-006-CHECKPOINT.md`. Somente ausência nesse caminho significa início. Reconcilie Git, log, diff e status, declare estado/divergências ao orquestrador antes de editar e nunca confie só na conversa. Somente o runner escreve o checkpoint.
