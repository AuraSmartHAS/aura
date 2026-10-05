-- =============================================================================================
-- AURA · consultas de demonstração da Fase 6
-- As functions dentro de SELECT comuns e as procedures chamadas por bloco anônimo.
-- No SQL Developer: posicione o cursor num bloco e use Ctrl+Enter (consulta) ou F5 (bloco).
-- Ligue a saída: View > Dbms Output (ou SET SERVEROUTPUT ON no sqlplus).
-- =============================================================================================
SET SERVEROUTPUT ON

-- ---------------------------------------------------------------------------------------------
-- BLOCO 1 · FN_TAXA_ADESAO (indicador): adesão à medicação nos últimos 7 dias, uma linha por casa
-- Doses confirmadas ÷ doses esperadas pelos horários (JSON) de cada medicação ativa.
-- ---------------------------------------------------------------------------------------------
SELECT h.label                             AS casa,
       fn_taxa_adesao(h.id, NULL, 7)       AS adesao_7_dias_pct
  FROM homes h
 ORDER BY adesao_7_dias_pct DESC NULLS LAST;

-- Por medicação, para ver de onde vem o número da casa
SELECT h.label                              AS casa,
       m.name                               AS medicacao,
       fn_taxa_adesao(m.home_id, m.id, 7)   AS adesao_7_dias_pct,
       m.stock_doses                        AS estoque
  FROM medications m
  JOIN homes h ON h.id = m.home_id
 WHERE m.active = 1
 ORDER BY h.label, m.name;

-- ---------------------------------------------------------------------------------------------
-- BLOCO 2 · FN_DESCREVER_LEITURA (dado formatado): o JSON cru da leitura vira frase
-- ---------------------------------------------------------------------------------------------
SELECT s.signal_value               AS como_esta_gravado,
       fn_descrever_leitura(s.id)   AS como_a_familia_le
  FROM signals s
  JOIN homes h ON h.id = s.home_id
 WHERE h.label = 'Casa da Maria'
 ORDER BY s.captured_at DESC
 FETCH FIRST 8 ROWS ONLY;

-- ---------------------------------------------------------------------------------------------
-- BLOCO 3 · FN_VARIACAO_ROTINA: últimos 3 dias da pulseira contra a média dos 14 anteriores
-- Compara a pessoa com ela mesma; não existe faixa clínica aqui.
-- ---------------------------------------------------------------------------------------------
SELECT h.label                                         AS casa,
       fn_variacao_rotina(h.id, 'steps')               AS passos_var_pct,
       fn_variacao_rotina(h.id, 'sleepHours')          AS sono_var_pct,
       fn_variacao_rotina(h.id, 'restingHeartRate')    AS fc_repouso_var_pct
  FROM homes h
 ORDER BY passos_var_pct NULLS LAST;

-- ---------------------------------------------------------------------------------------------
-- BLOCO 4 · Exceção tratada: casa sem histórico devolve vazio (NULL), não erro
-- ---------------------------------------------------------------------------------------------
SELECT fn_taxa_adesao(HEXTORAW('00000000000000000000000000000000'), NULL, 7)  AS adesao_casa_inexistente,
       fn_descrever_leitura(HEXTORAW('00000000000000000000000000000000'))     AS leitura_inexistente
  FROM dual;

-- ---------------------------------------------------------------------------------------------
-- BLOCO 5 · PRC_REGISTRAR_ALERTAS: CURSOR nas regras ativas, LOOP, IF por regra, INSERT
-- Rodar duas vezes: a segunda não cria nada (UNIQUE + DUP_VAL_ON_INDEX = idempotente).
-- ---------------------------------------------------------------------------------------------
DECLARE
  v_casa  RAW(16);
  v_novos NUMBER;
BEGIN
  SELECT id INTO v_casa FROM homes WHERE label = 'Casa do Seu Jorge';
  prc_registrar_alertas(p_home_id => v_casa, p_janela_horas => NULL, p_novos => v_novos);
  DBMS_OUTPUT.PUT_LINE('1ª chamada, avisos novos: ' || v_novos);
  prc_registrar_alertas(p_home_id => v_casa, p_janela_horas => NULL, p_novos => v_novos);
  DBMS_OUTPUT.PUT_LINE('2ª chamada, avisos novos: ' || v_novos || '  (não duplica)');
END;
/

-- Os avisos que o banco gravou, com a regra que disparou cada um
SELECT h.label       AS casa,
       a.regra,
       a.severidade,
       a.mensagem,
       a.status,
       TO_CHAR(a.criado_em AT TIME ZONE 'America/Sao_Paulo', 'DD/MM HH24:MI') AS quando
  FROM alerta a
  JOIN homes h ON h.id = a.home_id
 ORDER BY a.criado_em DESC
 FETCH FIRST 10 ROWS ONLY;

-- As regras moram no banco: mudar um limiar é um UPDATE auditável, não um deploy
SELECT codigo, descricao, severidade, limiar, janela_horas, versao FROM regra_alerta ORDER BY codigo;

-- ---------------------------------------------------------------------------------------------
-- BLOCO 6 · PRC_RELATORIO_CONSUMO: totais por OUT + uma linha por medicação no SYS_REFCURSOR
-- ---------------------------------------------------------------------------------------------
DECLARE
  v_casa        RAW(16);
  v_total_doses NUMBER;
  v_total_reais NUMBER;
  v_itens       SYS_REFCURSOR;
  v_med         VARCHAR2(255);
  v_conf        NUMBER;
  v_neg         NUMBER;
  v_esp         NUMBER;
  v_adesao      NUMBER;
  v_estoque     NUMBER;
  v_hoje        DATE := TRUNC(CAST(SYSTIMESTAMP AT TIME ZONE 'America/Sao_Paulo' AS DATE));
BEGIN
  SELECT id INTO v_casa FROM homes WHERE label = 'Casa do Seu Jorge';
  prc_relatorio_consumo(v_casa, v_hoje - 6, v_hoje, v_total_doses, v_total_reais, v_itens);

  DBMS_OUTPUT.PUT_LINE('Consumo da Casa do Seu Jorge, ' || TO_CHAR(v_hoje - 6, 'DD/MM')
                       || ' a ' || TO_CHAR(v_hoje, 'DD/MM'));
  DBMS_OUTPUT.PUT_LINE(RPAD('Medicação', 16) || RPAD('Conf.', 7) || RPAD('Não', 6)
                       || RPAD('Esper.', 8) || RPAD('Adesão', 9) || 'Estoque');
  LOOP
    FETCH v_itens INTO v_med, v_conf, v_neg, v_esp, v_adesao, v_estoque;
    EXIT WHEN v_itens%NOTFOUND;
    DBMS_OUTPUT.PUT_LINE(RPAD(v_med, 16) || RPAD(v_conf, 7) || RPAD(v_neg, 6) || RPAD(v_esp, 8)
                         || RPAD(NVL(TO_CHAR(v_adesao) || '%', 'sem dados'), 9) || NVL(TO_CHAR(v_estoque), '-'));
  END LOOP;
  CLOSE v_itens;
  DBMS_OUTPUT.PUT_LINE('Doses confirmadas no período: ' || v_total_doses);
  DBMS_OUTPUT.PUT_LINE('Demanda encaminhada a parceiros (preço de referência): R$ '
                       || TO_CHAR(v_total_reais, 'FM999G990D00', 'NLS_NUMERIC_CHARACTERS='',.'''));
END;
/

-- Exceção de negócio: período invertido vira ORA-20001 com mensagem em português
DECLARE
  v_casa RAW(16);
  v_d    NUMBER;
  v_r    NUMBER;
  v_c    SYS_REFCURSOR;
BEGIN
  SELECT id INTO v_casa FROM homes WHERE label = 'Casa do Seu Jorge';
  prc_relatorio_consumo(v_casa, SYSDATE, SYSDATE - 7, v_d, v_r, v_c);
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Recusado pelo banco: ' || SQLERRM);
END;
/

-- ---------------------------------------------------------------------------------------------
-- BLOCO 7 · PRC_CONSOLIDAR_INDICADORES: rotina diária, SAVEPOINT por casa
-- ---------------------------------------------------------------------------------------------
DECLARE
  v_casas NUMBER;
BEGIN
  prc_consolidar_indicadores(p_data_ref => NULL, p_casas => v_casas);
  DBMS_OUTPUT.PUT_LINE('Casas consolidadas: ' || v_casas);
END;
/

SELECT h.label                 AS casa,
       TO_CHAR(d.data_ref, 'DD/MM/YYYY') AS data_ref,
       d.adesao_pct,
       d.variacao_passos_pct,
       d.alertas_abertos,
       d.quase_quedas
  FROM indicador_diario d
  JOIN homes h ON h.id = d.home_id
 WHERE d.data_ref = TRUNC(CAST(SYSTIMESTAMP AT TIME ZONE 'America/Sao_Paulo' AS DATE))
 ORDER BY h.label;

-- Conferência final: nenhum objeto PL/SQL inválido
SELECT object_type, object_name, status
  FROM user_objects
 WHERE object_type IN ('FUNCTION', 'PROCEDURE')
 ORDER BY object_type, object_name;

-- As consultas acima não alteram dado do app; os blocos 5 e 7 gravam avisos e indicadores.
COMMIT;
