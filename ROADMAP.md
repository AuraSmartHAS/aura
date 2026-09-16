# Roadmap de execução

> **STOP — bootstrap de memória somente.** As tarefas `TASK-001` em diante aguardam ordem explícita humana. Uma tarefa marcada como TODO nunca é iniciada automaticamente. Uma nova instrução humana expressa para implementar uma task prevalece sobre este aviso; o runner registra a ativação no checkpoint antes do trabalho começar.

Exatamente uma task pode estar `- [-]`. Antes do despacho, o runner, sob instrução exata do orquestrador, registra no checkpoint canônico a autorização/reafirmação e o prompt/escopo, e muda apenas essa task para `- [-]`. Uma sessão nova retoma somente a task `- [-]`; nenhuma outra task pode usar esse estado.

## Estado atual

- [X] TASK-000 — Bootstrap da memória durável e configuração de papéis

## Competição: janela de 14 dias (somente após ordem explícita)

- [X] TASK-001 — Corrigir fronteiras de autorização e privilégios
- [X] TASK-002 — Tornar a infraestrutura da demonstração persistente e acessível na rede local
- [ ] TASK-003 — Implementar cadastro, consentimento e vínculo familiar por QR
- [ ] TASK-004 — Definir eventos de cuidado, idempotência, outbox e histórico compartilhado
- [ ] TASK-005 — Conectar o fluxo Flutter do idoso, texto e voz ao contrato de cuidado
- [ ] TASK-006 — Construir inbox, push e confirmações do familiar em React Native
- [ ] TASK-007 — Implementar ocorrências de medicamentos e confirmação idempotente
- [ ] TASK-008 — Corrigir autorização e estados honestos do SOS
- [ ] TASK-009 — Implementar recomendações explicáveis e catálogo Leroy verificável
- [X] TASK-010 — Catálogo multi-parceiro, página de parceiro e redirecionamento
- [ ] TASK-011 — Validar contratos, resiliência, acessibilidade e cenários negativos entre stacks
- [ ] TASK-012 — Validar a demonstração e preparar a apresentação da banca

## Pós-competição — bloqueado, fora de execução automática

- [ ] Hospedagem contínua, recuperação de conta e múltiplos cuidadores
- [ ] Integração transacional autorizada com parceiro comercial
- [ ] Wearable no dispositivo correto, mapas reais e estudos de métricas

## Regra de conclusão

Uma task só pode receber `- [X]` depois de evidência de execução aplicável, QA previsto, revisão independente, squash-merge e push verificados para `astra-main`. A atualização do roadmap entra em um commit curto de encerramento de memória, separado do commit de entrega. A exceção é `TASK-000`: revisão, commit local e reconciliação são suficientes; não há push neste bootstrap.
