-- =============================================================================================
-- AURA · consultas de demonstração das Fases 6 e 7
-- As functions dos packages dentro de SELECT comuns, as procedures chamadas por bloco anônimo,
-- as duas triggers em ação (blocos 8 e 9) e o Dynamic SQL do PKG_RELATORIO (bloco 10).
-- No SQL Developer: posicione o cursor num bloco e use Ctrl+Enter (consulta) ou F5 (bloco).
-- Ligue a saída: View > Dbms Output (ou SET SERVEROUTPUT ON no sqlplus).
-- =============================================================================================
SET SERVEROUTPUT ON

-- ---------------------------------------------------------------------------------------------
-- BLOCO 1 · PKG_MEDICACAO.TAXA_ADESAO (indicador): adesão à medicação nos últimos 7 dias, uma linha por casa
-- Doses confirmadas ÷ doses esperadas pelos horários (JSON) de cada medicação ativa.
-- ---------------------------------------------------------------------------------------------
SELECT h.label                             AS casa,
       pkg_medicacao.taxa_adesao(h.id, NULL, 7)       AS adesao_7_dias_pct
  FROM homes h
 ORDER BY adesao_7_dias_pct DESC NULLS LAST;

-- Por medicação, para ver de onde vem o número da casa
SELECT h.label                              AS casa,
       m.name                               AS medicacao,
       pkg_medicacao.taxa_adesao(m.home_id, m.id, 7)   AS adesao_7_dias_pct,
       m.stock_doses                        AS estoque
  FROM medications m
  JOIN homes h ON h.id = m.home_id
 WHERE m.active = 1
 ORDER BY h.label, m.name;

-- ---------------------------------------------------------------------------------------------
-- BLOCO 2 · PKG_LEITURA.DESCREVER (dado formatado): o JSON cru da leitura vira frase
-- ---------------------------------------------------------------------------------------------
SELECT s.signal_value               AS como_esta_gravado,
       pkg_leitura.descrever(s.id)   AS como_a_familia_le
  FROM signals s
  JOIN homes h ON h.id = s.home_id
 WHERE h.label = 'Casa da Maria'
 ORDER BY s.captured_at DESC
 FETCH FIRST 8 ROWS ONLY;

-- ---------------------------------------------------------------------------------------------
-- BLOCO 3 · PKG_LEITURA.VARIACAO_ROTINA: últimos 3 dias da pulseira contra a média dos 14 anteriores
-- Compara a pessoa com ela mesma; não existe faixa clínica aqui.
-- ---------------------------------------------------------------------------------------------
SELECT h.label                                         AS casa,
       pkg_leitura.variacao_rotina(h.id, 'steps')               AS passos_var_pct,
       pkg_leitura.variacao_rotina(h.id, 'sleepHours')          AS sono_var_pct,
       pkg_leitura.variacao_rotina(h.id, 'restingHeartRate')    AS fc_repouso_var_pct
  FROM homes h
 ORDER BY passos_var_pct NULLS LAST;

-- ---------------------------------------------------------------------------------------------
-- BLOCO 4 · Exceção tratada: casa sem histórico devolve vazio (NULL), não erro
-- ---------------------------------------------------------------------------------------------
SELECT pkg_medicacao.taxa_adesao(HEXTORAW('00000000000000000000000000000000'), NULL, 7)  AS adesao_casa_inexistente,
       pkg_leitura.descrever(HEXTORAW('00000000000000000000000000000000'))     AS leitura_inexistente
  FROM dual;

-- ---------------------------------------------------------------------------------------------
-- BLOCO 5 · PKG_ALERTAS.REGISTRAR_ALERTAS: CURSOR nas regras ativas, LOOP, IF por regra, INSERT
-- Rodar duas vezes: a segunda não cria nada (UNIQUE + DUP_VAL_ON_INDEX = idempotente).
-- ---------------------------------------------------------------------------------------------
DECLARE
  v_casa  RAW(16);
  v_novos NUMBER;
BEGIN
  SELECT id INTO v_casa FROM homes WHERE label = 'Casa do Seu Jorge';
  pkg_alertas.registrar_alertas(p_home_id => v_casa, p_janela_horas => NULL, p_novos => v_novos);
  DBMS_OUTPUT.PUT_LINE('1ª chamada, avisos novos: ' || v_novos);
  pkg_alertas.registrar_alertas(p_home_id => v_casa, p_janela_horas => NULL, p_novos => v_novos);
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

-- As regras moram no banco: mudar um limiar é um UPDATE auditável (bloco 8), não um deploy
SELECT codigo, descricao, severidade, limiar, janela_horas, versao FROM regra_alerta ORDER BY codigo;

-- ---------------------------------------------------------------------------------------------
-- BLOCO 6 · PKG_RELATORIO.CONSUMO: totais por OUT + uma linha por medicação no SYS_REFCURSOR
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
  pkg_relatorio.consumo(v_casa, v_hoje - 6, v_hoje, v_total_doses, v_total_reais, v_itens);

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
  pkg_relatorio.consumo(v_casa, SYSDATE, SYSDATE - 7, v_d, v_r, v_c);
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Recusado pelo banco: ' || SQLERRM);
END;
/

-- ---------------------------------------------------------------------------------------------
-- BLOCO 7 · PKG_RELATORIO.CONSOLIDAR_INDICADORES: rotina diária, SAVEPOINT por casa
-- ---------------------------------------------------------------------------------------------
DECLARE
  v_casas NUMBER;
BEGIN
  pkg_relatorio.consolidar_indicadores(p_data_ref => NULL, p_casas => v_casas);
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

-- ---------------------------------------------------------------------------------------------
-- BLOCO 8 · TRG_REGRA_ALERTA_AUDITORIA (Fase 7, auditoria): mudar um limiar deixa o antes e o depois
-- O primeiro UPDATE baixa a régua de adesão de 80% para 75%; o segundo devolve o valor original.
-- ---------------------------------------------------------------------------------------------
UPDATE regra_alerta SET limiar = 75, versao = '2026-11-demo' WHERE codigo = 'ADESAO_BAIXA';
UPDATE regra_alerta SET limiar = 80, versao = '2026-10' WHERE codigo = 'ADESAO_BAIXA';

SELECT codigo, operacao, limiar_antes, limiar_depois, versao_antes, versao_depois,
       usuario_banco, programa,
       TO_CHAR(alterado_em AT TIME ZONE 'America/Sao_Paulo', 'DD/MM HH24:MI:SS') AS quando
  FROM regra_alerta_hist
 ORDER BY id DESC
 FETCH FIRST 5 ROWS ONLY;

-- ---------------------------------------------------------------------------------------------
-- BLOCO 9 · TRG_MEDICACAO_ESTOQUE_BAIXO (Fase 7, automação): o estoque que cruza a linha vira aviso
-- Deixa o primeiro remédio da casa uma dose acima de 3 dias de cobertura e tira uma dose, como faz a
-- confirmação no app. O aviso é o mesmo que aparece no card "Avisos da casa" do painel.
-- Um aviso por remédio por dia: rodar de novo no mesmo dia não duplica.
-- ---------------------------------------------------------------------------------------------
DECLARE
  v_casa    RAW(16);
  v_med     RAW(16);
  v_por_dia NUMBER;
  v_dias    NUMBER;
BEGIN
  SELECT id INTO v_casa FROM homes WHERE label = 'Casa do Seu Jorge';
  SELECT id, pkg_medicacao.doses_por_dia(schedule)
    INTO v_med, v_por_dia
    FROM medications
   WHERE home_id = v_casa AND active = 1 AND pkg_medicacao.doses_por_dia(schedule) IS NOT NULL
   ORDER BY name
   FETCH FIRST 1 ROW ONLY;
  UPDATE medications SET stock_doses = v_por_dia * 3 + 1 WHERE id = v_med;  -- uma dose acima da linha
  UPDATE medications SET stock_doses = stock_doses - 1 WHERE id = v_med;    -- a dose que cruza
  SELECT pkg_medicacao.dias_cobertura(stock_doses, schedule) INTO v_dias FROM medications WHERE id = v_med;
  DBMS_OUTPUT.PUT_LINE('Cobertura agora: ' || v_dias || ' dias');
END;
/

SELECT h.label AS casa, a.regra, a.mensagem,
       TO_CHAR(a.criado_em AT TIME ZONE 'America/Sao_Paulo', 'DD/MM HH24:MI') AS quando
  FROM alerta a
  JOIN homes h ON h.id = a.home_id
 WHERE a.regra = 'ESTOQUE_BAIXO'
 ORDER BY a.criado_em DESC
 FETCH FIRST 5 ROWS ONLY;

-- ---------------------------------------------------------------------------------------------
-- BLOCO 10 · PKG_RELATORIO.CONSULTAR e AGRUPAR (Fase 7): Dynamic SQL em tempo real
-- Entidade, coluna do filtro e ordem são escolhidas na hora da chamada. Rode com F5 (script).
-- ---------------------------------------------------------------------------------------------
VARIABLE rc REFCURSOR
DECLARE
  v_casa RAW(16);
BEGIN
  SELECT id INTO v_casa FROM homes WHERE label = 'Casa do Seu Jorge';
  -- as 5 leituras da pulseira mais recentes da casa
  :rc := pkg_relatorio.consultar('SIGNALS', v_casa, p_coluna => 'TYPE', p_valor => 'VITALS', p_limite => 5);
END;
/
PRINT rc

DECLARE
  v_casa RAW(16);
BEGIN
  SELECT id INTO v_casa FROM homes WHERE label = 'Casa do Seu Jorge';
  -- quantos avisos de cada regra a casa já recebeu
  :rc := pkg_relatorio.agrupar('ALERTA', v_casa, 'REGRA');
END;
/
PRINT rc

-- As três defesas em ação: tabela fora da lista, coluna inexistente e injeção no nome da coluna
DECLARE
  v_casa RAW(16);
  v_rc   SYS_REFCURSOR;
  PROCEDURE tenta (p_entidade VARCHAR2, p_coluna VARCHAR2) IS
  BEGIN
    v_rc := pkg_relatorio.consultar(p_entidade, v_casa, p_coluna, 'x');
    DBMS_OUTPUT.PUT_LINE('Aceito: ' || p_entidade || '.' || p_coluna);
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('Recusado pelo banco: ' || SQLERRM);
  END tenta;
BEGIN
  SELECT id INTO v_casa FROM homes WHERE label = 'Casa do Seu Jorge';
  tenta('USERS', 'EMAIL');
  tenta('SIGNALS', 'PRESSAO');
  tenta('SIGNALS', 'TYPE = TYPE OR 1=1 --');
END;
/

-- Conferência final: as rotinas moram em packages e nada ficou inválido
SELECT object_type, object_name, status
  FROM user_objects
 WHERE object_type IN ('FUNCTION', 'PROCEDURE', 'PACKAGE', 'PACKAGE BODY', 'TRIGGER')
 ORDER BY object_type, object_name;

-- Os blocos 1 a 4 e 10 só leem; os blocos 5, 7, 8 e 9 gravam avisos, indicadores, histórico e estoque.
COMMIT;
