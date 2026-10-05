-- =============================================================================================
-- Passo 3 da carga: a tabela de preparo (preenchida pelo SQL*Loader a partir do CSV) vira
-- leitura da pulseira em SIGNALS, e a procedure de avisos olha todas as casas.
--
-- O JSON gravado é o mesmo que o app grava para a pulseira:
--   {"steps":4200,"heartRateResting":68,"sleepHours":7.4}
-- Chave fixa por casa+data (MD5 = 16 bytes = RAW(16)): rodar de novo não duplica.
-- =============================================================================================
SET DEFINE OFF
SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

PROMPT == Leituras da pulseira: preparo -> SIGNALS ==
MERGE INTO signals s
USING (
  SELECT STANDARD_HASH('pulseira|' || p.casa_id || '|' || TO_CHAR(dia.d, 'YYYYMMDD'), 'MD5') AS id,
         HEXTORAW(p.casa_id) AS home_id,
         '{"steps":' || p.passos
           || ',"heartRateResting":' || p.fc_repouso
           || ',"sleepHours":' || TO_CHAR(p.sono_horas, 'FM990.0', 'NLS_NUMERIC_CHARACTERS=''.,''')
           || '}' AS valor,
         -- A pulseira fecha o dia anterior às 07h da manhã, no fuso de São Paulo.
         FROM_TZ(CAST(dia.d AS TIMESTAMP) + INTERVAL '7' HOUR, 'America/Sao_Paulo') AS capturado
    FROM stg_leitura_pulseira p
    CROSS APPLY (SELECT TRUNC(CAST(SYSTIMESTAMP AT TIME ZONE 'America/Sao_Paulo' AS DATE)) - p.dias_atras AS d
                   FROM dual) dia
    -- Só casas que existem: linha de casa desconhecida não pode virar leitura órfã.
   WHERE EXISTS (SELECT 1 FROM homes h WHERE h.id = HEXTORAW(p.casa_id))
) l ON (s.id = l.id)
WHEN NOT MATCHED THEN INSERT (id, home_id, type, source, signal_value, captured_at)
VALUES (l.id, l.home_id, 'VITALS', 'WEARABLE', l.valor, l.capturado);

PROMPT == Avisos: PRC_REGISTRAR_ALERTAS em cada casa ==
-- No app, quem chama a procedure é o Java, a cada leitura nova que passa pela API. A carga e o
-- seed gravam direto no banco, sem esse evento; por isso chamamos uma vez por casa, cada regra
-- com a própria janela (NULL), para os avisos refletirem o histórico já existente.
DECLARE
  v_novos NUMBER;
  v_total NUMBER := 0;
BEGIN
  FOR casa IN (SELECT id, label FROM homes ORDER BY label) LOOP
    prc_registrar_alertas(p_home_id => casa.id, p_janela_horas => NULL, p_novos => v_novos);
    DBMS_OUTPUT.PUT_LINE(casa.label || ': ' || v_novos || ' aviso(s) novo(s)');
    v_total := v_total + v_novos;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('Total de avisos novos: ' || v_total);
END;
/

COMMIT;
PROMPT == Importação concluída ==
