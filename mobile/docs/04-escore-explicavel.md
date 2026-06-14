# 03 · Motor de escore explicável (algoritmo)

Risco = **soma ponderada de fatores observáveis** (0..1). Transparente e auditável.

## Passos
1. Coletar sinais da dimensão na janela (ex.: 14 dias).
2. Normalizar cada fator para 0..1 (ex.: `near_fall_reported` = 1/0; `no_grab_bar` vem do checklist da casa).
3. Aplicar pesos configuráveis por dimensão.
4. Somar ponderado → `score`.
5. Mapear faixa → nível: `<0.4` baixo · `<0.7` médio · `≥0.7` alto.
6. Montar explicação: fatores acionados + pesos + norma (NBR 9050).
7. Persistir em `scores` + `audit_log`.

## Exemplo (banheiro)
```
Risco = 0.4*near_fall_reported + 0.3*no_grab_bar + 0.2*slippery_floor + 0.1*dizziness_bath
near_fall=1, no_grab_bar=1, slippery=1, dizziness=0  →  score=0.90  →  ALTO
→ recomenda Kit Barra de Apoio 60cm (NBR 9050); motivo = fatores acima.
```
Config de fatores/pesos fica em arquivo/tabela **versionado** — nunca embutido "mágico" no código.
