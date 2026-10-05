-- Rotinas de apoio usadas pelas functions e procedures do AURA.
-- Repetível (R__): o Flyway reaplica sempre que o arquivo muda, por isso CREATE OR REPLACE.
-- Cada bloco PL/SQL termina com "/" sozinho na linha — é o delimitador que o Flyway reconhece.

/*
 * PRC_LOG_ERRO
 * Objetivo : registrar a falha de uma rotina sem depender da transação de quem falhou.
 * Parâmetros: p_origem (IN) nome da rotina; p_codigo (IN) SQLCODE; p_mensagem (IN) SQLERRM.
 * Por que AUTONOMOUS_TRANSACTION: quem chama normalmente relança o erro e a transação dele
 * sofre rollback; sem transação própria, o registro do erro seria desfeito junto.
 * Nunca recebe dado de saúde nem identificador de casa.
 */
CREATE OR REPLACE PROCEDURE prc_log_erro (
    p_origem   IN VARCHAR2,
    p_codigo   IN NUMBER,
    p_mensagem IN VARCHAR2
) AS
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    INSERT INTO log_erro_plsql (origem, codigo, mensagem)
    VALUES (SUBSTR(p_origem, 1, 60), p_codigo, SUBSTR(p_mensagem, 1, 1000));
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        -- O log nunca pode ser a causa de um segundo erro.
        ROLLBACK;
END prc_log_erro;
/

/*
 * FN_UUID_TEXTO
 * Objetivo : converter o RAW(16) que o Hibernate grava para o texto canônico do UUID
 *            (8-4-4-4-12, minúsculo), o mesmo formato que o Java grava dentro do JSON das leituras
 *            (ex.: {"medicationId":"3f2a..."}). Sem isso, não há como casar a coluna com o JSON.
 * Parâmetro: p_id (IN) RAW(16).
 * Retorno  : VARCHAR2(36), ou NULL para entrada nula.
 * Exemplo  : SELECT fn_uuid_texto(id) FROM homes;
 */
CREATE OR REPLACE FUNCTION fn_uuid_texto (p_id IN RAW) RETURN VARCHAR2
    DETERMINISTIC
AS
    v_hex VARCHAR2(32);
BEGIN
    IF p_id IS NULL THEN
        RETURN NULL;
    END IF;
    v_hex := LOWER(RAWTOHEX(p_id));
    RETURN SUBSTR(v_hex, 1, 8) || '-' || SUBSTR(v_hex, 9, 4) || '-' || SUBSTR(v_hex, 13, 4)
        || '-' || SUBSTR(v_hex, 17, 4) || '-' || SUBSTR(v_hex, 21, 12);
EXCEPTION
    WHEN VALUE_ERROR THEN
        RETURN NULL;
END fn_uuid_texto;
/
