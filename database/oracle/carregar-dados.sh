#!/usr/bin/env bash
# Carrega os dados simulados no Oracle do docker-compose.oracle.yml, em três passos:
#   1. carga-simulada.sql   casas, familiares, medicações, 21 dias de doses, histórico de SOS
#   2. sqlldr               CSV da pulseira -> tabela de preparo (importação real de arquivo)
#   3. importar-leituras.sql preparo -> SIGNALS e PRC_REGISTRAR_ALERTAS em cada casa
#
# Pré-requisito: o backend já subiu uma vez sobre o Oracle (o Flyway cria tabelas e PL/SQL; o
# seed cria as contas e o catálogo). Rodar de novo não duplica nada.
#
# Uso, na raiz do repositório:
#   export AURA_DB_PASSWORD='a-mesma-senha-do-compose'
#   ./database/oracle/carregar-dados.sh
set -euo pipefail

: "${AURA_DB_PASSWORD:?defina AURA_DB_PASSWORD (a mesma usada no docker compose)}"
RAIZ="$(cd "$(dirname "$0")/../.." && pwd)"
COMPOSE=(docker compose -f "$RAIZ/docker-compose.yml" -f "$RAIZ/docker-compose.oracle.yml")
CONEXAO="aura/${AURA_DB_PASSWORD}@//localhost:1521/FREEPDB1"

# Dentro do container: UTF-8 para os acentos chegarem inteiros, e a senha entra por variável de
# ambiente do exec, nunca por argumento visível em `ps` do host.
no_oracle() {
  "${COMPOSE[@]}" exec -T -e NLS_LANG=AMERICAN_AMERICA.AL32UTF8 -e CONEXAO="$CONEXAO" oracle bash -c "$1"
}

echo "== 1/3 Carga simulada"
no_oracle 'cd /opt/aura && sqlplus -S -L "$CONEXAO" @carga-simulada.sql'

echo "== 2/3 SQL*Loader: leituras-pulseira.csv"
no_oracle 'cd /opt/aura/dados && sqlldr userid="$CONEXAO" control=leituras-pulseira.ctl log=/tmp/pulseira.log bad=/tmp/pulseira.bad silent=header,feedback && grep -E "Rows? successfully loaded|Total logical records" /tmp/pulseira.log'

echo "== 3/3 Leituras da pulseira e avisos"
no_oracle 'cd /opt/aura && sqlplus -S -L "$CONEXAO" @importar-leituras.sql'

echo "Pronto. Abra o painel (localhost:4200) ou rode database/oracle/consultas-demo.sql no SQL Developer."
