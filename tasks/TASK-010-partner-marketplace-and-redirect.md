# TASK-010 — Catálogo multi-parceiro, página de parceiro e redirecionamento

> Esta task substitui "Restringir a logística ao operador e registrar histórico auditável" por decisão D-008, tomada após a 3ª Mentoria Enterprise Challenge de 01/09/2026. O escopo anterior morreu com a logística.

## Objetivo e escopo

A Leroy Merlin passa a ser um parceiro entre fornecedores, e não a loja única do produto. O catálogo ganha `partner` e `productUrl`; a recomendação aprovada leva a família ao site do parceiro; existe uma página de parceiros com o convite "seja um parceiro". A esteira de entrega sai da interface. Donos: `backend-java` e `web-frontend`.

## Dependências, contratos e migrações

Depende de `TASK-001` e `TASK-002`. Migração `V2__partner_and_product_url.sql` acrescenta duas colunas nuláveis a `products`; nulo é valor legítimo nas duas, porque item sem parceiro não pode ter a interface prometendo um link. `RecommendationResponse` e `CatalogItemResponse` passam a carregar os dois campos.

## Aceite

- O catálogo mostra mais de um fornecedor, e a recomendação diz quem vende o item.
- Depois da aprovação da família, existe caminho para o site do parceiro; sem link, nenhum botão é oferecido.
- Existe página de parceiros com quem já vende e o convite aos demais.
- Nenhuma tela acompanha entrega de terceiro.

## Verificação, QA, revisão e continuidade

Runner prova suíte, build do cliente e migração em PostgreSQL real. Revisor avalia o diff. Checkpoint registra evidência e o que ficou fora.

## Retomada após interrupção

Resolva o checkout canônico em `git worktree list --porcelain`: localize exatamente uma entrada `branch refs/heads/astra-main` e use seu path. Leia `ROADMAP.md`, `AGENTS.md`, `BLOCKERS.md`, as decisões recentes e `journal/TASK-010-CHECKPOINT.md`. Somente ausência desse arquivo significa início.
