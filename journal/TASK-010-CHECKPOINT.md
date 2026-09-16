# TASK-010 — Catálogo multi-parceiro, página de parceiro e redirecionamento

Estado: entregue e publicada. A task substituiu o escopo de logística ao operador por decisão D-008.

## Autorização

- Ordem explícita do usuário nesta sessão, priorizando o que a banca precisa ver sobre a ordem original do roadmap. As tasks 003 a 009, 011 e 012 permanecem TODO e serão reordenadas depois da gravação.
- Executada sob D-009: implementação e provas pelo orquestrador, revisão do diff pelo usuário.

## Entrega

- Squash-merge em `astra-main`: `f44c3364ea35c87c36e96ae36d23b119bdf4ab9a`, com `HEAD` e `origin/astra-main` confirmados nesse hash após o push.
- Mensagem literal: `feat(marketplace): partner catalog and redirect replace the delivery pipeline`.
- `origin/main` permanece `32f44e9bb0b68e5ded3c4fe6d93bbd0cbcd6652a`. Worktree e branch `task-p1/partner-marketplace` removidas após o push.

## Alterações entregues

- `Product` ganhou `partner` e `productUrl`; migração `V2__partner_and_product_url.sql`, ambas as colunas nuláveis.
- `RecommendationResponse` e `CatalogItemResponse` passam a carregar os dois campos.
- `DataSeeder` atribui `Leroy Merlin` ao catálogo e um segundo fornecedor ao consumível recorrente.
- Página `/parceiros` no Angular: quem já vende e o convite "seja um parceiro".
- Botão "Ver no site do parceiro" no card da recomendação, após a aprovação e apenas quando há link.
- Esteira de entrega fora da interface: card de pedidos da tela da família; OTIF, fill rate, lead time, pedidos abertos, pedidos por estágio e carteira de pedidos no admin. Permanecem os indicadores de cuidado.

## Evidência

- Suíte H2: 72 testes, 0 falhas, 0 erros, exit 0 — `/tmp/aura-p1-h2-20260915T225708.log`.
- PostgreSQL real, migrações V1 e V2 com `ddl-auto: validate`: 2 testes, 0 falhas, BUILD SUCCESS — `/tmp/aura-p1-pg-20260915T225815.log`.
- Build do Angular: bundle gerado, 396,76 kB — `/tmp/aura-p1-ng-build.log`.
- API viva: catálogo devolveu 104 itens `Leroy Merlin` e 1 `Rede Farma Cuidar (demonstração)`; as recomendações da casa devolveram parceiro e link preenchidos.

## Decisões tomadas na execução

- **Link é busca no site do parceiro, não URL de produto montada do SKU.** Sem acesso autorizado ao catálogo da Leroy (B-001), uma URL inventada daria 404 na apresentação; a busca sempre resolve e não promete o que não se verificou.
- **O segundo fornecedor é de demonstração e declarado como tal** no próprio nome. Nenhum nome de empresa real foi usado, o que implicaria parceria inexistente.
- **Correção factual da 3ª mentoria:** na Leroy a loja é o centro de distribuição e o único CD é o de Cajamar. Os nós do seed passaram de `Loja Marginal` e `CD Embu` para `Loja Marginal Tietê` e `CD Cajamar`; a asserção de `CareChainFlowTest` que fixava o nome antigo foi atualizada.

## Limites declarados

- `DeliveryOrder`, `OpsController` e `OpsService` continuam no backend. Removê-los atravessa oito arquivos de produção e sete de teste, risco desproporcional a poucos dias da banca. A logística saiu da interface, que foi o escopo aprovado; a remoção do backend fica para depois da entrega.
- A validação real com idosos continua pendente e não é código.

## Próximo passo

- Gravação do vídeo pitch, cujo roteiro já cobre esta tela no slide 09.
- Depois da entrega: reordenar o roadmap das tasks 003 a 009, 011 e 012 à luz de D-008, e decidir a remoção do backend de logística.
