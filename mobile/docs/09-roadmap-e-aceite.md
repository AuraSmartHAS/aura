# 09 · Roadmap e critérios de aceite (frontend)

## Ordem de construção
| Sprint | Construir | Resultado visível |
|---|---|---|
| S1 | tema/design system · router · login+LGPD · seleção de perfil | navega entre perfis |
| S2 | Home de voz (Maria) · Dashboard (Ana) · CRUD medicamento | núcleo de saúde |
| S3 | Painel 360 · Care-Chain (card explicável) · aprovar pedido | recomendação→pedido na tela |
| S4 | Mapa+rastreador · push FCM · wearable (`health`) · Web Admin (KPIs/fila) | conectividade + admin |
| S5 | Web Pessoa (portal+relatórios) · polimento de acessibilidade | superfícies web prontas |
| S6 | validação, gravação da demo, ajustes | pronto para entrega |
> "Pronto" por tela = navega + consome API real + estados (loading/empty/error) + checklist de a11y.

## Cenários de aceite (Dado / Quando / Então)
| ID | Dado | Quando | Então |
|---|---|---|---|
| UI-01 | Maria na Home de voz | toca o microfone e fala | vê transcrição ao vivo + confirmação por voz |
| UI-02 | STT indisponível | abre a Home | aparece **fallback de teclado** (≥48dp, RN-008) |
| UI-03 | risco ALTO | Ana abre a recomendação | vê produto + **fatores/pesos + NBR 9050** |
| UI-04 | recomendação na tela | Ana **não** aprova | nenhum pedido criado (RN-022) |
| UI-05 | pedido "em rota" | abre acompanhamento | vê rota + ETA no mapa |
| UI-06 | sem permissão de localização | abre o mapa | UI pede acesso, sem quebrar |
| UI-07 | wearable conectado | abre o 360 | vê passos/FC com selo "bem-estar, não diagnóstico" |
| UI-08 | qualquer tela | loading/vazio/erro | skeleton / estado vazio / retry |
| UI-09 | viewport ≥1024px | abre Admin | layout com sidebar; <1024 menu recolhe |
| UI-10 | qualquer recomendação | renderiza | **100%** mostram o porquê |
