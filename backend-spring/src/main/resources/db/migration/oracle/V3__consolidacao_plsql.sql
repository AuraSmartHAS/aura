-- Fase 7 · Consolidação em PL/SQL.
--
-- As nove rotinas soltas da Fase 6 passam a morar em cinco packages (R__01 a R__03) e o banco
-- ganha duas triggers (R__04). Esta migration faz só a parte que não se repete:
--   1. apaga as functions e procedures soltas, cujo código agora vive nos packages;
--   2. cria REGRA_ALERTA_HIST, a trilha de auditoria dos limiares de aviso;
--   3. cadastra a regra ESTOQUE_BAIXO, que a trigger de estoque consulta.

-- 1. Só apaga o que existe: num schema novo (CI, instalar-tudo.sql) as soltas nunca foram criadas.
BEGIN
    FOR o IN (SELECT object_type, object_name
                FROM user_objects
               WHERE object_type IN ('FUNCTION', 'PROCEDURE')
                 AND object_name IN ('FN_UUID_TEXTO', 'FN_DOSES_ESPERADAS', 'FN_TAXA_ADESAO',
                                     'FN_DESCREVER_LEITURA', 'FN_VARIACAO_ROTINA', 'PRC_LOG_ERRO',
                                     'PRC_REGISTRAR_ALERTAS', 'PRC_RELATORIO_CONSUMO',
                                     'PRC_CONSOLIDAR_INDICADORES')) LOOP
        EXECUTE IMMEDIATE 'DROP ' || o.object_type || ' ' || o.object_name;
    END LOOP;
END;
/

-- 2. Fase 6 prometia que "mudar um limiar é um UPDATE auditável, não um deploy". Com esta tabela e
-- a trigger TRG_REGRA_ALERTA_AUDITORIA a promessa passa a valer: toda mudança em REGRA_ALERTA,
-- venha de onde vier, deixa o antes e o depois. Sem FK para REGRA_ALERTA de propósito: o histórico
-- de uma regra apagada é justamente o que mais interessa.
CREATE TABLE regra_alerta_hist (
    id                NUMBER GENERATED ALWAYS AS IDENTITY,
    codigo            VARCHAR2(30 CHAR)           NOT NULL,
    operacao          VARCHAR2(6 CHAR)            NOT NULL,
    severidade_antes  VARCHAR2(10 CHAR),
    severidade_depois VARCHAR2(10 CHAR),
    limiar_antes      NUMBER(8,2),
    limiar_depois     NUMBER(8,2),
    janela_antes      NUMBER(5),
    janela_depois     NUMBER(5),
    ativa_antes       NUMBER(1),
    ativa_depois      NUMBER(1),
    versao_antes      VARCHAR2(20 CHAR),
    versao_depois     VARCHAR2(20 CHAR),
    usuario_banco     VARCHAR2(128 CHAR)          DEFAULT SYS_CONTEXT('USERENV', 'SESSION_USER') NOT NULL,
    -- "JDBC Thin Client" quando veio da API; "SQL Developer" ou "SQL*Plus" quando foi à mão.
    programa          VARCHAR2(64 CHAR)           DEFAULT SUBSTR(SYS_CONTEXT('USERENV', 'MODULE'), 1, 64),
    alterado_em       TIMESTAMP(6) WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_regra_alerta_hist PRIMARY KEY (id),
    CONSTRAINT ck_regra_alerta_hist_op CHECK (operacao IN ('INSERT', 'UPDATE', 'DELETE'))
);
CREATE INDEX idx_regra_alerta_hist_codigo ON regra_alerta_hist (codigo, alterado_em);

COMMENT ON TABLE regra_alerta_hist IS 'Auditoria dos limiares de aviso: uma linha por INSERT, UPDATE ou DELETE em REGRA_ALERTA (TRG_REGRA_ALERTA_AUDITORIA)';
COMMENT ON COLUMN regra_alerta_hist.programa IS 'Programa da sessão que mudou a regra: separa a API de uma alteração feita à mão';

-- 3. Avaliada no instante em que o estoque muda, pela trigger TRG_MEDICACAO_ESTOQUE_BAIXO, e não
-- pelo PKG_ALERTAS.REGISTRAR_ALERTAS. Limiar em dias de cobertura pela rotina declarada.
INSERT INTO regra_alerta (codigo, descricao, severidade, limiar, janela_horas, ativa, versao)
VALUES ('ESTOQUE_BAIXO', 'Estoque de remédio cobre o limiar de dias ou menos, pela rotina declarada', 'atencao', 3, 24, 1, '2026-11');
