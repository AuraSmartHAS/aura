-- Procedures do AURA: rotinas de backend executadas dentro do banco.
-- Nenhuma faz COMMIT: quem chama é o Spring, e a transação é dele. A única exceção é o
-- PRC_LOG_ERRO, que tem transação autônoma justamente para sobreviver ao rollback de quem falhou.
-- Erros de negócio usam a faixa -20xxx; o Java traduz cada código para uma resposta HTTP.

/*
 * PRC_REGISTRAR_ALERTAS — acionada pelo backend a cada leitura nova
 * Fluxo    : POST /api/v1/signals (ou confirmação de dose) -> Java publica LeituraRegistrada ->
 *            depois do commit, OracleCareIntelligence chama esta procedure por JDBC.
 *            Também roda sob demanda por POST /api/v1/homes/{id}/alertas/processar.
 * Objetivo : percorrer as regras ativas de REGRA_ALERTA e gravar em ALERTA o que disparou.
 * Parâmetros:
 *   p_home_id       (IN)  casa a examinar
 *   p_janela_horas  (IN)  sobrepõe a janela de todas as regras; NULL = a janela de cada regra
 *   p_novos         (OUT) quantos avisos novos foram gravados nesta execução
 * Lógica   : CURSOR nas regras ativas -> LOOP -> IF por regra -> INSERT. A unicidade
 *            (casa, regra, chave) torna a rotina idempotente: rodar duas vezes não duplica,
 *            o DUP_VAL_ON_INDEX é tratado como "já avisado".
 * Exceções : casa inexistente -> ORA-20404; qualquer outra falha é registrada em LOG_ERRO_PLSQL
 *            e relançada (quem chama decide; o Java só registra e segue).
 */
CREATE OR REPLACE PROCEDURE prc_registrar_alertas (
    p_home_id      IN  RAW,
    p_janela_horas IN  NUMBER DEFAULT NULL,
    p_novos        OUT NUMBER
) AS
    CURSOR c_regras IS
        SELECT codigo, severidade, limiar, janela_horas
          FROM regra_alerta
         WHERE ativa = 1
         ORDER BY codigo;

    CURSOR c_quase_quedas (p_desde TIMESTAMP WITH TIME ZONE) IS
        SELECT id
          FROM signals
         WHERE home_id = p_home_id
           AND type = 'MOBILITY'
           AND JSON_VALUE(signal_value, '$.event') = 'near_fall'
           AND captured_at > p_desde
         ORDER BY captured_at;

    c_nls   CONSTANT VARCHAR2(40) := 'NLS_NUMERIC_CHARACTERS = '',.''';
    v_hoje  CONSTANT VARCHAR2(8) := TO_CHAR(SYSTIMESTAMP AT TIME ZONE 'America/Sao_Paulo', 'YYYYMMDD');
    v_casas NUMBER;
    v_janela NUMBER;
    v_dias   NUMBER;
    v_desde  TIMESTAMP WITH TIME ZONE;
    v_valor  NUMBER;
    v_chave  VARCHAR2(64);

    -- Grava um aviso; se a mesma regra já avisou sobre a mesma chave, não faz nada.
    PROCEDURE registrar (
        p_regra      IN VARCHAR2,
        p_severidade IN VARCHAR2,
        p_mensagem   IN VARCHAR2,
        p_chave      IN VARCHAR2,
        p_signal_id  IN RAW DEFAULT NULL
    ) IS
    BEGIN
        INSERT INTO alerta (home_id, regra, severidade, mensagem, signal_id, chave_dedup)
        VALUES (p_home_id, p_regra, p_severidade, SUBSTR(p_mensagem, 1, 400), p_signal_id, p_chave);
        p_novos := p_novos + 1;
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            NULL;
    END registrar;
BEGIN
    p_novos := 0;

    SELECT COUNT(*) INTO v_casas FROM homes WHERE id = p_home_id;
    IF v_casas = 0 THEN
        RAISE_APPLICATION_ERROR(-20404, 'Casa não encontrada');
    END IF;

    FOR r IN c_regras LOOP
        v_janela := NVL(p_janela_horas, r.janela_horas);
        v_dias   := CEIL(v_janela / 24);
        v_desde  := SYSTIMESTAMP - NUMTODSINTERVAL(v_janela, 'HOUR');

        IF r.codigo = 'QUASE_QUEDA' THEN
            -- Um aviso por leitura: duas quase-quedas são duas conversas, não uma.
            FOR q IN c_quase_quedas(v_desde) LOOP
                registrar(r.codigo, r.severidade, fn_descrever_leitura(q.id), RAWTOHEX(q.id), q.id);
            END LOOP;

        ELSIF r.codigo = 'DOSES_NEGADAS' THEN
            -- A chave é a dose negada mais recente: o aviso só se repete quando há negação nova,
            -- e não a cada dia em que as mesmas doses de ontem continuam dentro da janela.
            SELECT COUNT(*), MAX(RAWTOHEX(id)) KEEP (DENSE_RANK LAST ORDER BY captured_at)
              INTO v_valor, v_chave
              FROM signals
             WHERE home_id = p_home_id
               AND type = 'ADHERENCE'
               AND JSON_VALUE(signal_value, '$.taken') = 'false'
               AND captured_at > v_desde
               AND captured_at <= SYSTIMESTAMP;
            IF v_valor >= r.limiar THEN
                registrar(r.codigo, r.severidade,
                          v_valor || ' doses não confirmadas nas últimas ' || v_janela || ' h',
                          v_chave);
            END IF;

        ELSIF r.codigo = 'ADESAO_BAIXA' THEN
            v_valor := fn_taxa_adesao(p_home_id, NULL, v_dias);
            IF v_valor IS NOT NULL AND v_valor < r.limiar THEN
                registrar(r.codigo, r.severidade,
                          'Adesão de ' || TO_CHAR(v_valor, 'FM990D0', c_nls) || '% nos últimos '
                          || v_dias || ' dias, pelas doses confirmadas no app',
                          v_hoje);
            END IF;

        ELSIF r.codigo = 'ROTINA_PASSOS' THEN
            v_valor := fn_variacao_rotina(p_home_id, 'steps', v_dias, 14);
            IF v_valor IS NOT NULL AND v_valor <= -r.limiar THEN
                registrar(r.codigo, r.severidade,
                          'Passos ' || TO_CHAR(ABS(v_valor), 'FM990') || '% abaixo da rotina da própria pessoa nos últimos '
                          || v_dias || ' dias',
                          v_hoje);
            END IF;
        END IF;
    END LOOP;
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE NOT BETWEEN -20999 AND -20000 THEN
            prc_log_erro('PRC_REGISTRAR_ALERTAS', SQLCODE, SQLERRM);
        END IF;
        RAISE;
END prc_registrar_alertas;
/

/*
 * PRC_RELATORIO_CONSUMO — relatório resumido de consumo da casa
 * Fluxo    : GET /api/v1/homes/{id}/relatorio-consumo?de=AAAA-MM-DD&ate=AAAA-MM-DD
 * Objetivo : por medicação, doses confirmadas, não confirmadas, esperadas, adesão e estoque no
 *            período; mais os totais da casa.
 * Parâmetros:
 *   p_home_id      (IN)  casa
 *   p_de, p_ate    (IN)  período em datas de Brasília, inclusivo nas duas pontas
 *   p_total_doses  (OUT) doses confirmadas no período, somadas por medicação (LOOP no cursor)
 *   p_total_reais  (OUT) demanda encaminhada a parceiros no período: soma do preço de
 *                        referência dos itens aprovados. Não é compra: a transação é do parceiro.
 *   p_itens        (OUT) SYS_REFCURSOR, uma linha por medicação ativa
 * Exceções : período inválido ou maior que um ano -> ORA-20001; casa inexistente -> ORA-20404.
 */
CREATE OR REPLACE PROCEDURE prc_relatorio_consumo (
    p_home_id     IN  RAW,
    p_de          IN  DATE,
    p_ate         IN  DATE,
    p_total_doses OUT NUMBER,
    p_total_reais OUT NUMBER,
    p_itens       OUT SYS_REFCURSOR
) AS
    CURSOR c_meds IS
        SELECT id FROM medications WHERE home_id = p_home_id AND active = 1;

    v_casas       NUMBER;
    v_inicio      TIMESTAMP WITH TIME ZONE;
    v_fim         TIMESTAMP WITH TIME ZONE;
    v_dias        NUMBER;
    v_confirmadas NUMBER;
BEGIN
    IF p_de IS NULL OR p_ate IS NULL OR TRUNC(p_ate) < TRUNC(p_de) THEN
        RAISE_APPLICATION_ERROR(-20001, 'Período inválido: a data final vem antes da inicial');
    END IF;
    IF TRUNC(p_ate) - TRUNC(p_de) > 366 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Período inválido: o relatório cobre no máximo um ano');
    END IF;

    SELECT COUNT(*) INTO v_casas FROM homes WHERE id = p_home_id;
    IF v_casas = 0 THEN
        RAISE_APPLICATION_ERROR(-20404, 'Casa não encontrada');
    END IF;

    -- O dia da família é o de Brasília, não o UTC do servidor.
    v_inicio := FROM_TZ(CAST(TRUNC(p_de) AS TIMESTAMP), 'America/Sao_Paulo');
    v_fim    := FROM_TZ(CAST(TRUNC(p_ate) + 1 AS TIMESTAMP), 'America/Sao_Paulo');
    v_dias   := TRUNC(p_ate) - TRUNC(p_de) + 1;

    p_total_doses := 0;
    FOR m IN c_meds LOOP
        SELECT COUNT(*)
          INTO v_confirmadas
          FROM signals s
         WHERE s.home_id = p_home_id
           AND s.type = 'ADHERENCE'
           AND JSON_VALUE(s.signal_value, '$.medicationId') = fn_uuid_texto(m.id)
           AND JSON_VALUE(s.signal_value, '$.taken') = 'true'
           AND s.captured_at >= v_inicio
           AND s.captured_at < v_fim;
        p_total_doses := p_total_doses + v_confirmadas;
    END LOOP;

    SELECT NVL(SUM(p.price), 0)
      INTO p_total_reais
      FROM recommendations r
      JOIN products p ON p.sku = r.sku
     WHERE r.home_id = p_home_id
       AND r.status = 'approved'
       AND r.created_at >= v_inicio
       AND r.created_at < v_fim;

    OPEN p_itens FOR
        SELECT m.name AS medicamento,
               (SELECT COUNT(*)
                  FROM signals s
                 WHERE s.home_id = p_home_id
                   AND s.type = 'ADHERENCE'
                   AND JSON_VALUE(s.signal_value, '$.medicationId') = fn_uuid_texto(m.id)
                   AND JSON_VALUE(s.signal_value, '$.taken') = 'true'
                   AND s.captured_at >= v_inicio
                   AND s.captured_at < v_fim) AS doses_confirmadas,
               (SELECT COUNT(*)
                  FROM signals s
                 WHERE s.home_id = p_home_id
                   AND s.type = 'ADHERENCE'
                   AND JSON_VALUE(s.signal_value, '$.medicationId') = fn_uuid_texto(m.id)
                   AND JSON_VALUE(s.signal_value, '$.taken') = 'false'
                   AND s.captured_at >= v_inicio
                   AND s.captured_at < v_fim) AS doses_negadas,
               -- Só os horários que já venceram, desde que a medicação começou a ser acompanhada.
               fn_doses_esperadas(m.id, v_inicio, v_fim) AS doses_esperadas,
               fn_taxa_adesao(p_home_id, m.id, v_dias, v_fim) AS adesao_pct,
               m.stock_doses AS estoque_doses
          FROM medications m
         WHERE m.home_id = p_home_id
           AND m.active = 1
         ORDER BY m.name;
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE NOT BETWEEN -20999 AND -20000 THEN
            prc_log_erro('PRC_RELATORIO_CONSUMO', SQLCODE, SQLERRM);
        END IF;
        RAISE;
END prc_relatorio_consumo;
/

/*
 * PRC_CONSOLIDAR_INDICADORES — rotina em lote (job diário)
 * Fluxo    : agendada no backend (perfil oracle) e sob demanda por
 *            POST /api/v1/ops/indicadores/consolidar (somente administrador).
 * Objetivo : gravar em INDICADOR_DIARIO, para cada casa, adesão de 7 dias, variação de passos,
 *            avisos em aberto e quase-quedas do dia. MERGE: rodar de novo no mesmo dia atualiza.
 * Parâmetros:
 *   p_data_ref (IN)  dia de referência (Brasília); NULL = hoje
 *   p_casas    (OUT) casas consolidadas com sucesso
 * Lógica   : CURSOR nas casas -> LOOP -> SAVEPOINT por casa. Se uma casa falhar, só o trabalho
 *            dela é desfeito (ROLLBACK TO SAVEPOINT), o erro vai para LOG_ERRO_PLSQL e o lote segue.
 *            Casa sem dado grava NULL, não zero: "sem dado" e "zero" são coisas diferentes.
 */
CREATE OR REPLACE PROCEDURE prc_consolidar_indicadores (
    p_data_ref IN  DATE DEFAULT NULL,
    p_casas    OUT NUMBER
) AS
    CURSOR c_casas IS
        SELECT id FROM homes ORDER BY created_at;

    v_data    DATE;
    v_inicio  TIMESTAMP WITH TIME ZONE;
    v_fim     TIMESTAMP WITH TIME ZONE;
    v_adesao  NUMBER;
    v_passos  NUMBER;
    v_abertos NUMBER;
    v_quedas  NUMBER;
BEGIN
    v_data   := NVL(TRUNC(p_data_ref), TRUNC(CAST(SYSTIMESTAMP AT TIME ZONE 'America/Sao_Paulo' AS DATE)));
    v_inicio := FROM_TZ(CAST(v_data AS TIMESTAMP), 'America/Sao_Paulo');
    v_fim    := FROM_TZ(CAST(v_data + 1 AS TIMESTAMP), 'America/Sao_Paulo');
    p_casas  := 0;

    FOR c IN c_casas LOOP
        SAVEPOINT sp_casa;
        BEGIN
            v_adesao := fn_taxa_adesao(c.id, NULL, 7, LEAST(v_fim, SYSTIMESTAMP));
            -- A variação compara com a rotina no momento da consolidação.
            v_passos := fn_variacao_rotina(c.id, 'steps');

            SELECT COUNT(*) INTO v_abertos
              FROM alerta
             WHERE home_id = c.id AND status = 'aberto';

            SELECT COUNT(*) INTO v_quedas
              FROM signals
             WHERE home_id = c.id
               AND type = 'MOBILITY'
               AND JSON_VALUE(signal_value, '$.event') = 'near_fall'
               AND captured_at >= v_inicio
               AND captured_at < v_fim;

            MERGE INTO indicador_diario d
            USING (SELECT c.id AS home_id, v_data AS data_ref FROM dual) x
               ON (d.home_id = x.home_id AND d.data_ref = x.data_ref)
             WHEN MATCHED THEN UPDATE
                  SET d.adesao_pct          = v_adesao,
                      d.variacao_passos_pct = v_passos,
                      d.alertas_abertos     = v_abertos,
                      d.quase_quedas        = v_quedas,
                      d.atualizado_em       = SYSTIMESTAMP
             WHEN NOT MATCHED THEN
                  INSERT (home_id, data_ref, adesao_pct, variacao_passos_pct, alertas_abertos, quase_quedas)
                  VALUES (x.home_id, x.data_ref, v_adesao, v_passos, v_abertos, v_quedas);

            p_casas := p_casas + 1;
        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK TO SAVEPOINT sp_casa;
                prc_log_erro('PRC_CONSOLIDAR_INDICADORES', SQLCODE, SQLERRM);
        END;
    END LOOP;
END prc_consolidar_indicadores;
/
