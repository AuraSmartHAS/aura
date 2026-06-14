# 02 · Monitoramento 360 do idoso (sem IoT)

Todas as dimensões são capturadas **por software** (voz, auto-relato, padrões de uso) + **wearable leve**. Cada sinal: (a) alerta a cuidadora, (b) **escala ao médico** quando crítico, (c) alimenta a cadeia logística.

| Dimensão | Como capturamos (sem hardware nosso) | Gancho logístico |
|---|---|---|
| Mobilidade | relato de quase-queda (voz/cuidadora), auto-avaliação | barras, rampas, antiderrapante |
| Atividade/rotina | frequência de uso do app, auto-relato | iluminação, organização |
| Sono/noturno | relato de idas noturnas | iluminação noturna com sensor (produto) |
| Cognição | confusão/repetição na voz, esquecimentos relatados | produtos de segurança (gás/fumaça) |
| Humor/isolamento | frequência/tom das conversas por voz | (cuidado, não produto) |
| Ambiente | questionário/auto-relato (frio, mofo, ar) | climatização, purificador |
| Vitais (**wearable leve**) | passos, FC de repouso, sono via pacote `health` (Health Connect/HealthKit) | (sinal, não produto) |

## Wearable (regra de implementação)
Usar o pacote Flutter **`health`** para ler **Health Connect (Android)** e **HealthKit (iOS)**. Opt-in. **Sem servidor de telemetria, sem MQTT.** É leitura do dispositivo do próprio usuário. Guardrail: bem-estar, **não diagnóstico**.
