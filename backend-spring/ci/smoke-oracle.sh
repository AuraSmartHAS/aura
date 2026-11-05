#!/usr/bin/env bash
# Smoke do deploy sobre Oracle (Fase 7): usa a API como o app e o painel usam e confere que cada
# package e a trigger de automação responderam. Não fala com o banco: só HTTP.
#   backend-spring/ci/smoke-oracle.sh [BASE_URL]        (padrão http://localhost:8080)
# Relatório em $SMOKE_REPORT (padrão smoke-report.md). Sai com 1 se algum passo falhar.
# Pode rodar de novo sobre o mesmo banco: o remédio do passo de estoque nasce com nome único.
set -uo pipefail

BASE="${1:-http://localhost:8080}"
API="$BASE/api/v1"
REPORT="${SMOKE_REPORT:-smoke-report.md}"
FALHAS=0

printf '| Passo | Resultado | Evidência |\n|---|---|---|\n' > "$REPORT"
check() { # nome, status (0 = ok), evidência
  local st="ok"
  if [ "$2" -ne 0 ]; then st="FALHOU"; FALHAS=$((FALHAS + 1)); fi
  printf '| %s | %s | `%s` |\n' "$1" "$st" "$(printf '%s' "$3" | tr '\n|' ' /' | cut -c1-150)" | tee -a "$REPORT"
}
ok() { "$@" >/dev/null 2>&1; echo $?; }
login() {
  curl -s -H 'Content-Type: application/json' -d "{\"email\":\"$1\",\"password\":\"aura1234\"}" \
    "$API/auth/login" | jq -r '.token // empty'
}
get() { curl -s -H "Authorization: Bearer $TOKEN" "$@"; }
post() { curl -s -X POST -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' "$@"; }

for _ in $(seq 1 90); do curl -sf "$API/health" >/dev/null && break; sleep 2; done

TOKEN=$(login ana@aura.com)
check "Login da Ana (seed no Oracle)" "$(ok test -n "$TOKEN")" "token ${TOKEN:0:12}..."

CASA=$(get "$API/homes" | jq -r '[.[] | select(.patientName == "Maria S.")][0].id // empty')
check "Casa da Maria" "$(ok test -n "$CASA")" "$CASA"

ALERTAS=$(get "$API/homes/$CASA/alertas")
check "API respondendo pelo Oracle" "$(ok jq -e '.engine == "oracle"' <<<"$ALERTAS")" "$(jq -c '{engine, avisos: (.alertas | length)}' <<<"$ALERTAS")"

PROC=$(post "$API/homes/$CASA/alertas/processar")
check "PKG_ALERTAS.REGISTRAR_ALERTAS" "$(ok jq -e '.novos | type == "number"' <<<"$PROC")" "$PROC"

CONSUMO=$(get "$API/homes/$CASA/relatorio-consumo")
check "PKG_RELATORIO.CONSUMO (cursor por remédio)" "$(ok jq -e '.itens | length > 0' <<<"$CONSUMO")" \
  "$(jq -c '{totalDoses, remedios: (.itens | length)}' <<<"$CONSUMO")"

# Trigger de automação: 2 doses/dia e 7 em estoque = 3,5 dias; a dose confirmada leva a 3,0 e cruza a linha.
NOME="Smoke $(date +%s)"
REMEDIO=$(post "$API/homes/$CASA/medications" \
  -d "{\"name\":\"$NOME\",\"schedule\":[\"08:00\",\"20:00\"],\"stockDoses\":7}" | jq -r '.id // empty')
post "$API/medications/$REMEDIO/confirm" -o /dev/null
AVISO=$(get "$API/homes/$CASA/alertas" | jq -r --arg n "$NOME" '[.alertas[].mensagem | select(contains($n))][0] // empty')
check "TRG_MEDICACAO_ESTOQUE_BAIXO na dose confirmada" "$(ok grep -q 'Estoque acabando' <<<"$AVISO")" "$AVISO"

SONO=$(get "$API/homes/$CASA/consulta?entidade=signals&coluna=type&valor=SLEEP&ordem=captured_at&limite=5")
check "PKG_RELATORIO.CONSULTAR (Dynamic SQL: filtro, ordem, limite)" \
  "$(ok jq -e '(.linhas | length) > 0 and (.linhas | length) <= 5 and all(.linhas[]; .type == "SLEEP")' <<<"$SONO")" \
  "$(jq -c '[.linhas[].type] | {tipos: unique, linhas: length}' <<<"$SONO")"

GRUPOS=$(get "$API/homes/$CASA/consulta/agrupada?entidade=alerta&coluna=regra")
check "PKG_RELATORIO.AGRUPAR (Dynamic SQL)" "$(ok jq -e 'any(.linhas[]; .valor == "ESTOQUE_BAIXO")' <<<"$GRUPOS")" \
  "$(jq -c '[.linhas[] | "\(.valor)=\(.total)"]' <<<"$GRUPOS")"

HTTP=$(get "$API/homes/$CASA/consulta?entidade=users" -o /dev/null -w '%{http_code}')
check "Lista branca recusa a tabela users" "$(ok test "$HTTP" = 400)" "HTTP $HTTP"
HTTP=$(get -G "$API/homes/$CASA/consulta" --data-urlencode 'entidade=signals' \
  --data-urlencode 'coluna=type = type OR 1=1 --' -o /dev/null -w '%{http_code}')
check "Injeção no nome da coluna recusada" "$(ok test "$HTTP" = 400)" "HTTP $HTTP"

TOKEN=$(login admin@aura.com)
CONSOLIDA=$(post "$API/ops/indicadores/consolidar")
check "PKG_RELATORIO.CONSOLIDAR_INDICADORES (admin)" "$(ok jq -e '.casasProcessadas > 0' <<<"$CONSOLIDA")" "$CONSOLIDA"

echo
echo "Falhas: $FALHAS" | tee -a "$REPORT"
exit $(( FALHAS > 0 ))
