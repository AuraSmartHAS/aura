#!/usr/bin/env bash
# Gera instalar-tudo.sql a partir das migrations do Flyway: as versionadas (V*) em ordem de versão
# e depois as repetíveis (R__*) em ordem alfabética, que é a mesma ordem em que o Flyway as aplica.
# Gerado, nunca editado à mão: assim o script do SQL Developer e o schema do app não divergem.
#
# Uso, na raiz do repositório:  ./database/oracle/gerar-script-unico.sh
set -euo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
MIGRATIONS="$AQUI/../../backend-spring/src/main/resources/db/migration/oracle"
SAIDA="$AQUI/instalar-tudo.sql"

{
  cat <<'CABECALHO'
-- =============================================================================================
-- AURA · instalação completa do schema Oracle (tabelas + functions + procedures)
-- ARQUIVO GERADO por database/oracle/gerar-script-unico.sh a partir das migrations do Flyway.
-- Não edite aqui: edite a migration e gere de novo.
--
-- Rode conectado ao SEU usuário (SQL Developer: F5, "executar script"; ou sqlplus @instalar-tudo.sql).
-- Se o usuário já tiver alguma tabela com nome do AURA, o script para antes de criar qualquer
-- coisa. Ele nunca apaga tabela existente: trabalho de outra disciplina não corre risco.
-- =============================================================================================
SET DEFINE OFF
SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

DECLARE
  v_conflitos VARCHAR2(4000);
BEGIN
  SELECT LISTAGG(table_name, ', ') WITHIN GROUP (ORDER BY table_name)
    INTO v_conflitos
    FROM user_tables
   WHERE table_name IN ('USERS', 'HOMES', 'HOME_MEMBERS', 'CONSENTS', 'SIGNALS', 'SCORES',
                        'PRODUCTS', 'STOCK_NODES', 'MEDICATIONS', 'RECOMMENDATIONS', 'ORDERS',
                        'EMERGENCIES', 'REGRA_ALERTA', 'ALERTA', 'INDICADOR_DIARIO', 'LOG_ERRO_PLSQL');
  IF v_conflitos IS NOT NULL THEN
    RAISE_APPLICATION_ERROR(-20900,
      'Instalação interrompida: o usuário já tem as tabelas ' || v_conflitos
      || '. Use um usuário vazio; este script não apaga nada.');
  END IF;
END;
/

CABECALHO

  # sort -V no nome: V2 antes de V10, como o Flyway.
  for nome in $(cd "$MIGRATIONS" && ls V*__*.sql | sort -V) $(cd "$MIGRATIONS" && ls R__*.sql | sort); do
    echo
    echo "PROMPT == $nome =="
    cat "$MIGRATIONS/$nome"
    echo
  done

  cat <<'RODAPE'

PROMPT == Conferência: objetos inválidos (o esperado é nenhum) ==
SELECT object_type, object_name FROM user_objects WHERE status = 'INVALID';

COMMIT;
PROMPT == Instalação concluída ==
RODAPE
} > "$SAIDA"

echo "Gerado: $SAIDA ($(wc -l < "$SAIDA" | tr -d ' ') linhas)"
