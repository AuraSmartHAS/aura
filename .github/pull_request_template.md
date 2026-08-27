## O que este PR entrega

<!-- 1–3 linhas. Qual tela/feature, qual fase do doc 09. -->

Tela: `features/____/screens/____Screen.tsx` · Fase: ____ · Bug herdado coberto: R-__ (ou n/a: ____)

## Screenshots — antes (Flutter) / depois (RN)

| Antes | Depois | Fonte do SO 200% |
|---|---|---|
| (cole) | (cole) | (cole, se é tela da Maria) |

## Definition of Done

Funcional
- [ ] Registrada no `RootNavigator` e alcançável pelo pouso por role
- [ ] 4 estados assíncronos: loading · erro **com retry que funciona no 1º erro** · vazio · ready
- [ ] Zero `fetch` na tela (só `useXxxQuery`/`useXxxMutation` da feature); nenhuma escrita disparada no mount

Testes
- [ ] Teste de fluxo em `features/<x>/__tests__/` (caminho feliz + 1 de erro)
- [ ] Teste de regressão do bug herdado (R-__) escrito **antes** do port
- [ ] `npm test` verde na suíte inteira

Estático
- [ ] `npx tsc --noEmit` limpo · nenhum `@ts-ignore` novo (ou justificado abaixo)
- [ ] `npm run lint` limpo (hex fora do theme · import cruzado · `fontSize` < 13 · fetch em tela)

Acessibilidade (WCAG 2.1 AA — critério de aceite, não polimento)
- [ ] `accessibilityRole` + `accessibilityLabel` pt-BR em todo controle tocável
- [ ] Alvo de toque ≥ 48 em tudo que se toca
- [ ] `fontSize` só da escala tipográfica (piso 13) — nenhum número mágico
- [ ] Contraste AA nos pares novos (`confirm`, não `careGreen`, em CTA) · severidade = ícone + texto
- [ ] Strings pt-BR centralizadas em `core/i18n/pt.ts` · nenhuma exceção crua em `<Text>`
- [ ] `accessibilityLiveRegion` nos status que mudam sozinhos

## Revisão
- [ ] Revisor designado (≠ autor) — pareamento obrigatório se é **voz** ou **backend** (§8 do doc 10)
- [ ] Diff ≤ ~400 linhas, ou explicação de por que não deu para quebrar

## Notas para o revisor / dívida assumida
<!-- O que ficou de fora de propósito, e onde está registrado. -->
