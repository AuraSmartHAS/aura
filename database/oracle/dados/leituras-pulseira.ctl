-- SQL*Loader: importa as leituras diárias da pulseira (passos, frequência cardíaca de repouso,
-- horas de sono) para a tabela de preparo STG_LEITURA_PULSEIRA.
--
-- A data não vem no arquivo: vem "dias_atras", e o importar-leituras.sql converte para a data
-- relativa a hoje. Assim a carga continua recente no dia em que alguém a rodar.
--
-- Uso (o carregar-dados.sh já faz isto dentro do container; log e bad vão para /tmp porque a
-- pasta montada é somente leitura):
--   sqlldr userid=aura/<senha>@//localhost:1521/FREEPDB1 control=leituras-pulseira.ctl \
--          log=/tmp/pulseira.log bad=/tmp/pulseira.bad
OPTIONS (SKIP=1, ERRORS=0)
LOAD DATA
CHARACTERSET UTF8
INFILE 'leituras-pulseira.csv'
TRUNCATE
INTO TABLE stg_leitura_pulseira
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
TRAILING NULLCOLS
(
  casa_id     CHAR(32),
  dias_atras  INTEGER EXTERNAL,
  passos      INTEGER EXTERNAL,
  fc_repouso  INTEGER EXTERNAL,
  -- Ponto decimal fixo no arquivo, qualquer que seja o NLS da sessão.
  sono_horas  CHAR "TO_NUMBER(:sono_horas, '99D9', 'NLS_NUMERIC_CHARACTERS=''.,''')"
)
