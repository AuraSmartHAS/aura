# 🎬 Roteiro do vídeo — Fase 5 (até 5 min, YouTube não listado)

> Antes de gravar, deixe rodando: `./mvnw spring-boot:run` (8080), `npm start` no
> `web-admin` (4200) e `npm run web` no `mobile-rn` (8081). Abra as abas na ordem em
> que vão aparecer. Faça login como `ana@aura.com` / `aura1234` antes de começar.

| Tempo | Tela | O que dizer |
|---|---|---|
| 0:00–0:30 | Slide 1 e 2 | Quem somos (nome + RM) e o que é o AURA: saúde domiciliar voice-first para idosos com Parkinson, com cadeia logística de segurança da casa. |
| 0:30–1:00 | Slide 3 | Onde o projeto está: Kotlin (F3) → Flutter + Care-Chain (F4) → nesta fase, API própria em Spring Boot, painel Angular e app React Native. Os três clientes falam com o mesmo contrato. |
| 1:00–1:40 | Slide 4 | **Parte 1**: a decisão de stack. Migração parcial para React Native do fluxo crítico, mantendo o Flutter como app principal — e por quê. Mostrar a tabela de comparação. |
| 1:40–2:40 | **Swagger ao vivo** (`localhost:8080/swagger-ui.html`) | **Parte 2**: mostrar os grupos de rotas, autenticar com o botão *Authorize*, executar `POST /scores/recompute` e **ler a resposta na tela**: `level: high`, `score: 0.9`, os três fatores e seus pesos. Frisar: o escore é explicável e os pesos vivem em YAML versionado. Mostrar rapidamente a página de status (Thymeleaf) em `localhost:8080/`. |
| 2:40–3:30 | **Painel Angular** (`localhost:4200`) | **Parte 3**: login, tela da casa — desmarcar “Barra de apoio no banheiro”, salvar, **Recalcular escore** e ver o risco subir com os fatores. Gerar recomendação, aprovar e avançar o pedido na linha do tempo. Ir em Torre de Controle e mostrar os KPIs saindo dos pedidos reais + o CRUD do catálogo. |
| 3:30–4:20 | **App React Native** (`localhost:8081`, janela estreita) | Login, painel da cuidadora com o mesmo risco, abrir a Care-Chain, aprovar e ver o pedido andando. Dizer: mesma API, nenhuma rota criada para o app novo. |
| 4:20–4:45 | Terminal | `./mvnw test` — **50** testes verdes (fluxo ponta a ponta, isolamento entre pacientes, RBAC, guardrail de não-prescrição e o ciclo da medicação). Diga **50**, que é o que o terminal mostra e o que a documentação afirma — e **168 no projeto inteiro**. |
| 4:45–5:00 | Slide 9 e 10 | Impacto (prevenir a queda, decisão sempre humana), próximos passos e agradecimento. |

## Frases-âncora

- “O AURA **nunca prescreve nem diagnostica** — o guardrail está no caminho de saída da API.”
- “Nenhum pedido nasce sem a **aprovação da cuidadora** — e isso é verificado por teste.”
- “Os pesos do risco **não estão no código**: estão num YAML versionado, auditável por quem não programa.”
- “Trocamos de stack no mobile e de linguagem no backend **sem reescrever o produto**, porque o contrato é o ponto de encontro.”

## Depois de publicar

1. Suba o vídeo como **não listado** e copie o link.
2. Substitua o marcador nos dois HTML de `docs/fase5/` e gere os PDFs de novo:
   ```bash
   cd docs/fase5
   sed -i '' 's|«inserir link do YouTube (não listado)»|https://youtu.be/SEU_ID|' documentacao.html slides.html
   ```
3. Atualize também o `Equipe e Links.txt` da pasta de entrega.
