-- Packages de procedures (Fase 7): PKG_ALERTAS e PKG_RELATORIO.
-- Mesmo nome de arquivo da Fase 6, pelo mesmo motivo de R__02_functions.sql. PKG_ALERTAS vem antes
-- porque nada aqui depende dele; os dois usam PKG_APOIO (R__01), PKG_LEITURA e PKG_MEDICACAO (R__02).

-- PKG_ALERTAS: o banco que avisa. Toda gravação em ALERTA passa por aqui.
-- Fase 6 → Fase 7: PRC_REGISTRAR_ALERTAS → PKG_ALERTAS.REGISTRAR_ALERTAS
-- Nova na Fase 7: AVISAR_ESTOQUE, chamada pela trigger TRG_MEDICACAO_ESTOQUE_BAIXO.
-- Nenhuma rotina faz COMMIT: a transação é de quem chama (o Spring ou a escrita que disparou a trigger).

CREATE OR REPLACE PACKAGE pkg_alertas AS

    /*
     * REGISTRAR_ALERTAS: acionada pelo backend a cada leitura nova
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
     *            o DUP_VAL_ON_INDEX é tratado como "já avisado". ESTOQUE_BAIXO não é avaliada aqui:
     *            quem a avalia é a trigger, no instante em que o estoque muda.
     * Exceções : casa inexistente -> ORA-20404; qualquer outra falha é registrada em LOG_ERRO_PLSQL
     *            e relançada (quem chama decide; o Java só registra e segue).
     */
    PROCEDURE registrar_alertas (
        p_home_id      IN  RAW,
        p_janela_horas IN  NUMBER DEFAULT NULL,
        p_novos        OUT NUMBER
    );

    /*
     * AVISAR_ESTOQUE: chamada pela trigger TRG_MEDICACAO_ESTOQUE_BAIXO
     * Objetivo : gravar o aviso ESTOQUE_BAIXO quando a cobertura do remédio cruza o limiar da regra,
     *            de acima para igual ou abaixo. Só na travessia: as doses seguintes, já abaixo da
     *            linha, não repetem o aviso.
     * Parâmetros (IN): casa, medicação e nome; estoque novo; dias de cobertura antes e depois
     *            (calculados pela trigger com PKG_MEDICACAO.DIAS_COBERTURA sobre :OLD e :NEW).
     * Lógica   : o limiar vem de REGRA_ALERTA, como o das outras regras; regra com ATIVA = 0 não avisa.
     *            Chave = medicação + dia de Brasília: um aviso por remédio por dia, mesmo que o
     *            estoque suba e caia de novo no mesmo dia.
     */
    PROCEDURE avisar_estoque (
        p_home_id       IN RAW,
        p_medication_id IN RAW,
        p_nome          IN VARCHAR2,
        p_estoque_doses IN NUMBER,
        p_dias_antes    IN NUMBER,
        p_dias_depois   IN NUMBER
    );

END pkg_alertas;
/

CREATE OR REPLACE PACKAGE BODY pkg_alertas AS

    c_nls CONSTANT VARCHAR2(40) := 'NLS_NUMERIC_CHARACTERS = '',.''';

    -- Grava um aviso e devolve 1; se a mesma regra já avisou sobre a mesma chave, devolve 0.
    FUNCTION gravar (
        p_home_id    IN RAW,
        p_regra      IN VARCHAR2,
        p_severidade IN VARCHAR2,
        p_mensagem   IN VARCHAR2,
        p_chave      IN VARCHAR2,
        p_signal_id  IN RAW DEFAULT NULL
    ) RETURN PLS_INTEGER IS
    BEGIN
        INSERT INTO alerta (home_id, regra, severidade, mensagem, signal_id, chave_dedup)
        VALUES (p_home_id, p_regra, p_severidade, SUBSTR(p_mensagem, 1, 400), p_signal_id, p_chave);
        RETURN 1;
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            RETURN 0;
    END gravar;

    PROCEDURE registrar_alertas (
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

        v_hoje   CONSTANT VARCHAR2(8) := TO_CHAR(SYSTIMESTAMP AT TIME ZONE 'America/Sao_Paulo', 'YYYYMMDD');
        v_casas  NUMBER;
        v_janela NUMBER;
        v_dias   NUMBER;
        v_desde  TIMESTAMP WITH TIME ZONE;
        v_valor  NUMBER;
        v_chave  VARCHAR2(64);
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
                    p_novos := p_novos + gravar(p_home_id, r.codigo, r.severidade,
                                                pkg_leitura.descrever(q.id), RAWTOHEX(q.id), q.id);
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
                    p_novos := p_novos + gravar(p_home_id, r.codigo, r.severidade,
                                                v_valor || ' doses não confirmadas nas últimas ' || v_janela || ' h',
                                                v_chave);
                END IF;

            ELSIF r.codigo = 'ADESAO_BAIXA' THEN
                v_valor := pkg_medicacao.taxa_adesao(p_home_id, NULL, v_dias);
                IF v_valor IS NOT NULL AND v_valor < r.limiar THEN
                    p_novos := p_novos + gravar(p_home_id, r.codigo, r.severidade,
                                                'Adesão de ' || TO_CHAR(v_valor, 'FM990D0', c_nls) || '% nos últimos '
                                                || v_dias || ' dias, pelas doses confirmadas no app',
                                                v_hoje);
                END IF;

            ELSIF r.codigo = 'ROTINA_PASSOS' THEN
                v_valor := pkg_leitura.variacao_rotina(p_home_id, 'steps', v_dias, 14);
                IF v_valor IS NOT NULL AND v_valor <= -r.limiar THEN
                    p_novos := p_novos + gravar(p_home_id, r.codigo, r.severidade,
                                                'Passos ' || TO_CHAR(ABS(v_valor), 'FM990') || '% abaixo da rotina da própria pessoa nos últimos '
                                                || v_dias || ' dias',
                                                v_hoje);
                END IF;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE NOT BETWEEN -20999 AND -20000 THEN
                pkg_apoio.log_erro('PKG_ALERTAS.REGISTRAR_ALERTAS', SQLCODE, SQLERRM);
            END IF;
            RAISE;
    END registrar_alertas;

    PROCEDURE avisar_estoque (
        p_home_id       IN RAW,
        p_medication_id IN RAW,
        p_nome          IN VARCHAR2,
        p_estoque_doses IN NUMBER,
        p_dias_antes    IN NUMBER,
        p_dias_depois   IN NUMBER
    ) AS
        v_limiar     regra_alerta.limiar%TYPE;
        v_severidade regra_alerta.severidade%TYPE;
        v_gravados   PLS_INTEGER;
    BEGIN
        SELECT limiar, severidade
          INTO v_limiar, v_severidade
          FROM regra_alerta
         WHERE codigo = 'ESTOQUE_BAIXO'
           AND ativa = 1;

        -- NULL em p_dias_depois (sem estoque ou sem horário) não cruza nada.
        IF p_dias_depois <= v_limiar AND (p_dias_antes IS NULL OR p_dias_antes > v_limiar) THEN
            v_gravados := gravar(p_home_id, 'ESTOQUE_BAIXO', v_severidade,
                                 'Estoque acabando · ' || p_nome || ': ' || p_estoque_doses
                                 || ' doses, cobertura de ' || TO_CHAR(p_dias_depois, 'FM990D0', c_nls)
                                 || ' dias pela rotina declarada',
                                 RAWTOHEX(p_medication_id) || '-'
                                 || TO_CHAR(SYSTIMESTAMP AT TIME ZONE 'America/Sao_Paulo', 'YYYYMMDD'));
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            NULL; -- regra desativada ou removida: nada a avisar
    END avisar_estoque;

END pkg_alertas;
/

-- PKG_RELATORIO: relatórios e consultas da casa e da operação.
-- Fase 6 → Fase 7: PRC_RELATORIO_CONSUMO      → PKG_RELATORIO.CONSUMO
--                  PRC_CONSOLIDAR_INDICADORES → PKG_RELATORIO.CONSOLIDAR_INDICADORES
-- Novas na Fase 7: CONSULTAR e AGRUPAR, as consultas em tempo real com Dynamic SQL.
-- Nenhuma rotina faz COMMIT: quem chama é o Spring, e a transação é dele.
-- Erros de negócio usam a faixa -20xxx; o Java traduz cada código para uma resposta HTTP.

CREATE OR REPLACE PACKAGE pkg_relatorio AS

    /*
     * CONSUMO: relatório resumido de consumo da casa
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
    PROCEDURE consumo (
        p_home_id     IN  RAW,
        p_de          IN  DATE,
        p_ate         IN  DATE,
        p_total_doses OUT NUMBER,
        p_total_reais OUT NUMBER,
        p_itens       OUT SYS_REFCURSOR
    );

    /*
     * CONSOLIDAR_INDICADORES: rotina em lote (job diário)
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
    PROCEDURE consolidar_indicadores (
        p_data_ref IN  DATE DEFAULT NULL,
        p_casas    OUT NUMBER
    );

    /*
     * CONSULTAR: consulta em tempo real com Dynamic SQL
     * Fluxo    : GET /api/v1/homes/{id}/consulta?entidade=signals&coluna=type&valor=SLEEP&limite=20
     * Objetivo : responder perguntas que ninguém previu ("o sono desta semana", "os SOS confirmados",
     *            "os avisos de estoque") sem uma rota nova por pergunta. Entidade, coluna de filtro,
     *            ordenação e limite são escolhidos na hora; o SELECT é montado em texto e aberto com
     *            OPEN ... FOR ... USING.
     * Parâmetros (IN):
     *   p_entidade  SIGNALS, MEDICATIONS, EMERGENCIES, ALERTA, INDICADOR_DIARIO, RECOMMENDATIONS,
     *               ORDERS ou SCORES
     *   p_home_id   casa (a API só a passa depois de conferir que o usuário tem acesso a ela)
     *   p_coluna    coluna do filtro por igualdade (opcional)
     *   p_valor     valor do filtro, no mesmo formato em que a consulta devolve a coluna
     *   p_ordem     coluna da ordenação, decrescente (padrão: o carimbo de tempo da entidade)
     *   p_limite    linhas, de 1 a 500 (padrão 50)
     * Retorno  : SYS_REFCURSOR. Ids saem como UUID (PKG_APOIO.UUID_TEXTO) e datas em ISO-8601, no
     *            mesmo formato do resto da API.
     * Segurança: cada pedaço do texto tem uma defesa. A entidade passa por lista branca; as colunas
     *            precisam existir em USER_TAB_COLUMNS e entram citadas por DBMS_ASSERT.ENQUOTE_NAME;
     *            casa, valor e limite vão sempre por bind, nunca concatenados. USERS e CONSENTS não
     *            estão na lista: dado pessoal fica fora da consulta.
     * Exceções : entidade fora da lista -> ORA-20100; coluna inexistente -> ORA-20101. Valor que não
     *            converte para o tipo da coluna não casa com nada (lista vazia), nunca vira erro.
     * Exemplo  : VARIABLE rc REFCURSOR
     *            EXEC :rc := pkg_relatorio.consultar('ALERTA', HEXTORAW('...'), 'REGRA', 'ESTOQUE_BAIXO')
     *            PRINT rc
     */
    FUNCTION consultar (
        p_entidade IN VARCHAR2,
        p_home_id  IN RAW,
        p_coluna   IN VARCHAR2 DEFAULT NULL,
        p_valor    IN VARCHAR2 DEFAULT NULL,
        p_ordem    IN VARCHAR2 DEFAULT NULL,
        p_limite   IN NUMBER   DEFAULT 50
    ) RETURN SYS_REFCURSOR;

    /*
     * AGRUPAR: contagem agrupada em tempo real com Dynamic SQL
     * Fluxo    : GET /api/v1/homes/{id}/consulta/agrupada?entidade=alerta&coluna=regra
     * Objetivo : quantas linhas há para cada valor de uma coluna escolhida na hora (avisos por regra,
     *            leituras por tipo, SOS por estado). Mesmas defesas e exceções de CONSULTAR.
     * Retorno  : SYS_REFCURSOR com VALOR e TOTAL, maiores primeiro, no máximo 500 grupos.
     */
    FUNCTION agrupar (
        p_entidade IN VARCHAR2,
        p_home_id  IN RAW,
        p_coluna   IN VARCHAR2
    ) RETURN SYS_REFCURSOR;

END pkg_relatorio;
/

CREATE OR REPLACE PACKAGE BODY pkg_relatorio AS

    c_max_linhas CONSTANT PLS_INTEGER := 500;

    PROCEDURE consumo (
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
               AND JSON_VALUE(s.signal_value, '$.medicationId') = pkg_apoio.uuid_texto(m.id)
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
                       AND JSON_VALUE(s.signal_value, '$.medicationId') = pkg_apoio.uuid_texto(m.id)
                       AND JSON_VALUE(s.signal_value, '$.taken') = 'true'
                       AND s.captured_at >= v_inicio
                       AND s.captured_at < v_fim) AS doses_confirmadas,
                   (SELECT COUNT(*)
                      FROM signals s
                     WHERE s.home_id = p_home_id
                       AND s.type = 'ADHERENCE'
                       AND JSON_VALUE(s.signal_value, '$.medicationId') = pkg_apoio.uuid_texto(m.id)
                       AND JSON_VALUE(s.signal_value, '$.taken') = 'false'
                       AND s.captured_at >= v_inicio
                       AND s.captured_at < v_fim) AS doses_negadas,
                   -- Só os horários que já venceram, desde que a medicação começou a ser acompanhada.
                   pkg_medicacao.doses_esperadas(m.id, v_inicio, v_fim) AS doses_esperadas,
                   pkg_medicacao.taxa_adesao(p_home_id, m.id, v_dias, v_fim) AS adesao_pct,
                   m.stock_doses AS estoque_doses
              FROM medications m
             WHERE m.home_id = p_home_id
               AND m.active = 1
             ORDER BY m.name;
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE NOT BETWEEN -20999 AND -20000 THEN
                pkg_apoio.log_erro('PKG_RELATORIO.CONSUMO', SQLCODE, SQLERRM);
            END IF;
            RAISE;
    END consumo;

    PROCEDURE consolidar_indicadores (
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
                v_adesao := pkg_medicacao.taxa_adesao(c.id, NULL, 7, LEAST(v_fim, SYSTIMESTAMP));
                -- A variação compara com a rotina no momento da consolidação.
                v_passos := pkg_leitura.variacao_rotina(c.id, 'steps');

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
                    pkg_apoio.log_erro('PKG_RELATORIO.CONSOLIDAR_INDICADORES', SQLCODE, SQLERRM);
            END;
        END LOOP;
    END consolidar_indicadores;

    -- ── Dynamic SQL ──────────────────────────────────────────────────────────────────────────────

    -- Primeira defesa: a entidade vem de uma lista fixa, nunca do texto de quem chama.
    FUNCTION tabela_segura (p_entidade IN VARCHAR2) RETURN VARCHAR2 IS
        v_tabela VARCHAR2(128) := UPPER(TRIM(p_entidade));
    BEGIN
        IF v_tabela IS NULL OR v_tabela NOT IN ('SIGNALS', 'MEDICATIONS', 'EMERGENCIES', 'ALERTA',
                                                'INDICADOR_DIARIO', 'RECOMMENDATIONS', 'ORDERS', 'SCORES') THEN
            RAISE_APPLICATION_ERROR(-20100, 'Entidade fora da consulta: ' || SUBSTR(NVL(p_entidade, '(vazia)'), 1, 100));
        END IF;
        RETURN v_tabela;
    END tabela_segura;

    -- Segunda defesa: a coluna precisa existir na tabela. O dicionário de dados é a lista branca, e o
    -- nome volta citado pelo DBMS_ASSERT, pronto para entrar no texto do SQL.
    PROCEDURE coluna_segura (
        p_tabela IN  VARCHAR2,
        p_coluna IN  VARCHAR2,
        p_nome   OUT VARCHAR2,
        p_tipo   OUT VARCHAR2
    ) IS
        v_coluna user_tab_columns.column_name%TYPE;
    BEGIN
        SELECT column_name, data_type
          INTO v_coluna, p_tipo
          FROM user_tab_columns
         WHERE table_name = p_tabela
           AND column_name = UPPER(TRIM(p_coluna));
        p_nome := DBMS_ASSERT.ENQUOTE_NAME(v_coluna, FALSE);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20101, 'Coluna inexistente em ' || p_tabela || ': '
                                    || SUBSTR(NVL(p_coluna, '(vazia)'), 1, 100));
    END coluna_segura;

    -- Como cada tipo sai: id como UUID, data em ISO-8601, o resto como está no banco.
    FUNCTION exibir (p_coluna IN VARCHAR2, p_tipo IN VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN CASE
                   WHEN p_tipo = 'RAW' THEN 'pkg_apoio.uuid_texto(' || p_coluna || ')'
                   WHEN p_tipo LIKE 'TIMESTAMP%' THEN
                       'TO_CHAR(' || p_coluna || ', ''YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM'')'
                   WHEN p_tipo = 'DATE' THEN 'TO_CHAR(' || p_coluna || ', ''YYYY-MM-DD'')'
                   ELSE p_coluna
               END;
    END exibir;

    -- O filtro compara no mesmo formato em que o valor sai, e nunca converte de um jeito que possa
    -- falhar: um id copiado de qualquer rota funciona, e texto num campo numérico só não encontra nada.
    FUNCTION filtro (p_coluna IN VARCHAR2, p_tipo IN VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN CASE
                   WHEN p_tipo = 'RAW' THEN exibir(p_coluna, p_tipo) || ' = LOWER(TRIM(:valor))'
                   WHEN p_tipo LIKE 'TIMESTAMP%' OR p_tipo = 'DATE' THEN exibir(p_coluna, p_tipo) || ' = TRIM(:valor)'
                   WHEN p_tipo IN ('NUMBER', 'FLOAT') THEN
                       p_coluna || ' = TO_NUMBER(:valor DEFAULT NULL ON CONVERSION ERROR)'
                   ELSE p_coluna || ' = :valor'
               END;
    END filtro;

    -- Sem ordem pedida, o carimbo de tempo da entidade: created_at, criado_em, captured_at ou data_ref.
    FUNCTION ordem_padrao (p_tabela IN VARCHAR2) RETURN VARCHAR2 IS
        v_coluna user_tab_columns.column_name%TYPE;
    BEGIN
        SELECT MIN(column_name) KEEP (DENSE_RANK FIRST
                   ORDER BY CASE WHEN column_name IN ('CREATED_AT', 'CRIADO_EM', 'CAPTURED_AT', 'DATA_REF')
                                 THEN 0 ELSE 1 END, column_id)
          INTO v_coluna
          FROM user_tab_columns
         WHERE table_name = p_tabela
           AND (data_type = 'DATE' OR data_type LIKE 'TIMESTAMP%');
        RETURN v_coluna;
    END ordem_padrao;

    FUNCTION consultar (
        p_entidade IN VARCHAR2,
        p_home_id  IN RAW,
        p_coluna   IN VARCHAR2 DEFAULT NULL,
        p_valor    IN VARCHAR2 DEFAULT NULL,
        p_ordem    IN VARCHAR2 DEFAULT NULL,
        p_limite   IN NUMBER   DEFAULT 50
    ) RETURN SYS_REFCURSOR
    AS
        v_tabela VARCHAR2(128);
        v_limite PLS_INTEGER := LEAST(GREATEST(NVL(TRUNC(p_limite), 50), 1), c_max_linhas);
        v_lista  VARCHAR2(4000);
        v_sql    VARCHAR2(8000);
        v_coluna VARCHAR2(130);
        v_ordem  VARCHAR2(130);
        v_tipo   user_tab_columns.data_type%TYPE;
        v_cursor SYS_REFCURSOR;
    BEGIN
        v_tabela := tabela_segura(p_entidade);

        FOR c IN (SELECT column_name, data_type
                    FROM user_tab_columns
                   WHERE table_name = v_tabela
                   ORDER BY column_id) LOOP
            v_coluna := DBMS_ASSERT.ENQUOTE_NAME(c.column_name, FALSE);
            v_lista  := v_lista || CASE WHEN v_lista IS NOT NULL THEN ', ' END
                        || exibir(v_coluna, c.data_type) || ' AS ' || v_coluna;
        END LOOP;

        v_sql := 'SELECT ' || v_lista || ' FROM ' || v_tabela || ' WHERE home_id = :casa';
        IF p_coluna IS NOT NULL THEN
            coluna_segura(v_tabela, p_coluna, v_coluna, v_tipo);
            v_sql := v_sql || ' AND ' || filtro(v_coluna, v_tipo);
        END IF;
        coluna_segura(v_tabela, NVL(p_ordem, ordem_padrao(v_tabela)), v_ordem, v_tipo);
        v_sql := v_sql || ' ORDER BY ' || v_ordem || ' DESC NULLS LAST FETCH FIRST :limite ROWS ONLY';

        -- Terceira defesa: casa, valor e limite entram por bind.
        IF p_coluna IS NULL THEN
            OPEN v_cursor FOR v_sql USING p_home_id, v_limite;
        ELSE
            OPEN v_cursor FOR v_sql USING p_home_id, p_valor, v_limite;
        END IF;
        RETURN v_cursor;
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE NOT BETWEEN -20999 AND -20000 THEN
                pkg_apoio.log_erro('PKG_RELATORIO.CONSULTAR', SQLCODE, SQLERRM);
            END IF;
            RAISE;
    END consultar;

    FUNCTION agrupar (
        p_entidade IN VARCHAR2,
        p_home_id  IN RAW,
        p_coluna   IN VARCHAR2
    ) RETURN SYS_REFCURSOR
    AS
        v_tabela VARCHAR2(128);
        v_coluna VARCHAR2(130);
        v_tipo   user_tab_columns.data_type%TYPE;
        v_valor  VARCHAR2(400);
        v_cursor SYS_REFCURSOR;
    BEGIN
        v_tabela := tabela_segura(p_entidade);
        coluna_segura(v_tabela, p_coluna, v_coluna, v_tipo);
        v_valor := exibir(v_coluna, v_tipo);

        OPEN v_cursor FOR
            'SELECT ' || v_valor || ' AS "VALOR", COUNT(*) AS "TOTAL" FROM ' || v_tabela
            || ' WHERE home_id = :casa GROUP BY ' || v_valor
            || ' ORDER BY 2 DESC, 1 FETCH FIRST :limite ROWS ONLY'
            USING p_home_id, c_max_linhas;
        RETURN v_cursor;
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE NOT BETWEEN -20999 AND -20000 THEN
                pkg_apoio.log_erro('PKG_RELATORIO.AGRUPAR', SQLCODE, SQLERRM);
            END IF;
            RAISE;
    END agrupar;

END pkg_relatorio;
/
