-- Packages de functions (Fase 7): PKG_LEITURA e PKG_MEDICACAO.
-- O arquivo guarda o nome da Fase 6, quando estas mesmas rotinas eram functions soltas: assim um banco
-- que já aplicou a Fase 6 só reaplica a repetível, sem migration "sumida" para o Flyway reclamar.

-- PKG_LEITURA: o que as leituras (SIGNALS) dizem, em frase e em tendência.
-- Fase 6 → Fase 7: FN_DESCREVER_LEITURA → PKG_LEITURA.DESCREVER
--                  FN_VARIACAO_ROTINA   → PKG_LEITURA.VARIACAO_ROTINA
-- A autorização (quem pode ver qual casa) é do Java, antes da chamada: o PL/SQL recebe só o id.

CREATE OR REPLACE PACKAGE pkg_leitura AS

    /*
     * DESCREVER: dado formatado
     * Objetivo : transformar uma leitura crua (tipo + JSON) numa frase que a família entende,
     *            no formato "o quê · onde · como · quando". É o texto dos avisos e das consultas.
     *            Exemplos: "Quase-queda registrada · banheiro · por voz · 04/10 14:32"
     *                      "Pulseira: 1.800 passos · sono 5,6 h · FC em repouso 79 bpm · 04/10 08:00"
     * Parâmetro: p_signal_id (IN) id da leitura em SIGNALS.
     * Retorno  : VARCHAR2 (até 300 caracteres), horário de Brasília.
     * Exceções : leitura inexistente -> 'Leitura não encontrada'; qualquer outra falha devolve o tipo
     *            cru, para nunca derrubar a lista de avisos por causa de um JSON inesperado.
     * Guardrail: o texto descreve o que foi observado. Nunca orienta dose nem diagnostica.
     */
    FUNCTION descrever (p_signal_id IN RAW) RETURN VARCHAR2;

    /*
     * VARIACAO_ROTINA: mudança de rotina percebida pela pulseira
     * Objetivo : comparar a média recente de uma métrica da pulseira com a linha de base da PRÓPRIA
     *            pessoa (as semanas anteriores). Não usa faixa clínica: 1.800 passos pode ser normal
     *            para alguém e queda forte para outra pessoa.
     * Parâmetros (IN):
     *   p_home_id        casa
     *   p_metrica        'steps' | 'sleepHours' | 'restingHeartRate'
     *   p_dias_recentes  janela recente (padrão 3 dias)
     *   p_dias_base      linha de base imediatamente anterior (padrão 14 dias)
     * Retorno  : NUMBER, % de variação (ex.: -45.2 = 45,2% abaixo da rotina), ou NULL sem dado
     *            suficiente nas duas janelas.
     * Exceções : métrica desconhecida -> ORA-20003; divisão por zero -> NULL.
     * Exemplo  : SELECT pkg_leitura.variacao_rotina(id, 'steps') FROM homes;
     */
    FUNCTION variacao_rotina (
        p_home_id       IN RAW,
        p_metrica       IN VARCHAR2,
        p_dias_recentes IN NUMBER DEFAULT 3,
        p_dias_base     IN NUMBER DEFAULT 14
    ) RETURN NUMBER;

END pkg_leitura;
/

CREATE OR REPLACE PACKAGE BODY pkg_leitura AS

    c_nls CONSTANT VARCHAR2(40) := 'NLS_NUMERIC_CHARACTERS = '',.''';

    FUNCTION lugar (p_codigo IN VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN CASE p_codigo
                   WHEN 'bathroom'    THEN 'banheiro'
                   WHEN 'bedroom'     THEN 'quarto'
                   WHEN 'kitchen'     THEN 'cozinha'
                   WHEN 'corridor'    THEN 'corredor'
                   WHEN 'living_room' THEN 'sala'
                   ELSE p_codigo
               END;
    END lugar;

    FUNCTION descrever (p_signal_id IN RAW) RETURN VARCHAR2
    AS
        v_tipo     signals.type%TYPE;
        v_origem   signals.source%TYPE;
        v_json     signals.signal_value%TYPE;
        v_quando   signals.captured_at%TYPE;
        v_evento   VARCHAR2(40);
        v_texto    VARCHAR2(300);
        v_remedio  medications.name%TYPE;
        v_passos   NUMBER;
        v_sono     NUMBER;
        v_fc       NUMBER;
    BEGIN
        SELECT type, source, signal_value, captured_at
          INTO v_tipo, v_origem, v_json, v_quando
          FROM signals
         WHERE id = p_signal_id;

        v_evento := JSON_VALUE(v_json, '$.event');

        IF v_tipo = 'MOBILITY' AND v_evento = 'near_fall' THEN
            v_texto := 'Quase-queda registrada';
        ELSIF v_tipo = 'MOBILITY' AND v_evento = 'dizziness' THEN
            v_texto := 'Tontura relatada';
        ELSIF v_tipo = 'MOBILITY' AND v_evento = 'sos' THEN
            v_texto := 'Pedido de socorro';
        ELSIF v_tipo = 'SLEEP' AND v_evento = 'night_trip' THEN
            v_texto := 'Idas ao banheiro de madrugada: ' || JSON_VALUE(v_json, '$.times');
        ELSIF v_tipo = 'COGNITION' AND v_evento = 'confusion' THEN
            v_texto := 'Confusão percebida na conversa';
        ELSIF v_tipo = 'ENVIRONMENT' AND v_evento = 'poor_air' THEN
            v_texto := 'Ar abafado';
        ELSIF v_tipo = 'ADHERENCE' THEN
            BEGIN
                SELECT m.name INTO v_remedio
                  FROM medications m
                 WHERE pkg_apoio.uuid_texto(m.id) = JSON_VALUE(v_json, '$.medicationId');
            EXCEPTION
                WHEN NO_DATA_FOUND THEN v_remedio := NULL;
            END;
            v_texto := CASE JSON_VALUE(v_json, '$.taken')
                           WHEN 'true' THEN 'Dose confirmada'
                           ELSE 'Dose não confirmada'
                       END || CASE WHEN v_remedio IS NOT NULL THEN ' · ' || v_remedio END;
        ELSIF v_tipo = 'VITALS' THEN
            v_passos := JSON_VALUE(v_json, '$.steps' RETURNING NUMBER);
            v_sono   := JSON_VALUE(v_json, '$.sleepHours' RETURNING NUMBER);
            -- O seed grava heartRateResting e o app Flutter envia restingHeartRate: aceitamos as duas.
            v_fc     := COALESCE(JSON_VALUE(v_json, '$.heartRateResting' RETURNING NUMBER),
                                 JSON_VALUE(v_json, '$.restingHeartRate' RETURNING NUMBER));
            v_texto := 'Pulseira:'
                || CASE WHEN v_passos IS NOT NULL THEN ' ' || TO_CHAR(v_passos, 'FM999G999G990', c_nls) || ' passos' END
                || CASE WHEN v_sono IS NOT NULL THEN ' · sono ' || TO_CHAR(v_sono, 'FM990D0', c_nls) || ' h' END
                || CASE WHEN v_fc IS NOT NULL THEN ' · FC em repouso ' || TO_CHAR(v_fc, 'FM990') || ' bpm' END;
        ELSE
            v_texto := INITCAP(v_tipo);
        END IF;

        -- Onde aconteceu (só quando a leitura diz).
        IF JSON_VALUE(v_json, '$.place') IS NOT NULL THEN
            v_texto := v_texto || ' · ' || lugar(JSON_VALUE(v_json, '$.place'));
        ELSIF JSON_VALUE(v_json, '$.room') IS NOT NULL THEN
            v_texto := v_texto || ' · ' || JSON_VALUE(v_json, '$.room');
        END IF;

        -- Como chegou ao AURA.
        v_texto := v_texto || ' · ' || CASE v_origem
                                           WHEN 'VOICE'       THEN 'por voz'
                                           WHEN 'SELF_REPORT' THEN 'pelo app'
                                           WHEN 'USAGE'       THEN 'pelo uso do app'
                                           WHEN 'WEARABLE'    THEN 'pela pulseira'
                                           ELSE LOWER(v_origem)
                                       END;

        -- Quando, no horário de quem cuida.
        RETURN SUBSTR(v_texto || ' · '
                      || TO_CHAR(v_quando AT TIME ZONE 'America/Sao_Paulo', 'DD/MM HH24:MI'), 1, 300);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 'Leitura não encontrada';
        WHEN OTHERS THEN
            pkg_apoio.log_erro('PKG_LEITURA.DESCREVER', SQLCODE, SQLERRM);
            RETURN NVL(INITCAP(v_tipo), 'Leitura');
    END descrever;

    FUNCTION variacao_rotina (
        p_home_id       IN RAW,
        p_metrica       IN VARCHAR2,
        p_dias_recentes IN NUMBER DEFAULT 3,
        p_dias_base     IN NUMBER DEFAULT 14
    ) RETURN NUMBER
    AS
        v_agora    TIMESTAMP WITH TIME ZONE := SYSTIMESTAMP;
        v_corte    TIMESTAMP WITH TIME ZONE;
        v_inicio   TIMESTAMP WITH TIME ZONE;
        v_recente  NUMBER;
        v_base     NUMBER;
    BEGIN
        -- Sem o IS NULL, uma métrica nula passaria pelo NOT IN (que dá NULL) e cairia calada no ramo da FC.
        IF p_metrica IS NULL OR p_metrica NOT IN ('steps', 'sleepHours', 'restingHeartRate') THEN
            RAISE_APPLICATION_ERROR(-20003, 'Métrica da pulseira desconhecida: ' || NVL(p_metrica, '(vazia)'));
        END IF;
        v_corte  := v_agora - NUMTODSINTERVAL(p_dias_recentes, 'DAY');
        v_inicio := v_corte - NUMTODSINTERVAL(p_dias_base, 'DAY');

        -- O caminho do JSON_VALUE precisa ser literal no 19c; por isso o CASE em vez de concatenar.
        SELECT AVG(CASE WHEN s.captured_at > v_corte THEN valor END),
               AVG(CASE WHEN s.captured_at <= v_corte THEN valor END)
          INTO v_recente, v_base
          FROM (SELECT s.captured_at,
                       CASE p_metrica
                           WHEN 'steps' THEN JSON_VALUE(s.signal_value, '$.steps' RETURNING NUMBER)
                           WHEN 'sleepHours' THEN JSON_VALUE(s.signal_value, '$.sleepHours' RETURNING NUMBER)
                           ELSE COALESCE(JSON_VALUE(s.signal_value, '$.heartRateResting' RETURNING NUMBER),
                                         JSON_VALUE(s.signal_value, '$.restingHeartRate' RETURNING NUMBER))
                       END AS valor
                  FROM signals s
                 WHERE s.home_id = p_home_id
                   AND s.type = 'VITALS'
                   AND s.captured_at > v_inicio
                   AND s.captured_at <= v_agora) s;

        IF v_recente IS NULL OR v_base IS NULL THEN
            RETURN NULL;
        END IF;
        RETURN ROUND((v_recente - v_base) / v_base * 100, 1);
    EXCEPTION
        WHEN ZERO_DIVIDE THEN
            RETURN NULL;
        WHEN OTHERS THEN
            IF SQLCODE = -20003 THEN
                RAISE;
            END IF;
            pkg_apoio.log_erro('PKG_LEITURA.VARIACAO_ROTINA', SQLCODE, SQLERRM);
            RAISE;
    END variacao_rotina;

END pkg_leitura;
/

-- PKG_MEDICACAO: adesão e estoque, a partir da rotina declarada de remédios.
-- Fase 6 → Fase 7: FN_DOSES_ESPERADAS → PKG_MEDICACAO.DOSES_ESPERADAS
--                  FN_TAXA_ADESAO     → PKG_MEDICACAO.TAXA_ADESAO
-- Novas na Fase 7: DOSES_POR_DIA e DIAS_COBERTURA, usadas pela trigger de estoque.

CREATE OR REPLACE PACKAGE pkg_medicacao AS

    /*
     * DOSES_ESPERADAS: quantas doses a rotina declarada pedia num período (apoio)
     * Objetivo : contar os horários do schedule (JSON) que JÁ VENCERAM entre p_de e p_ate, a partir do
     *            dia em que a medicação passou a ser acompanhada (cadastro ou primeira confirmação no
     *            app, o que vier antes). Remédio cadastrado ontem não deve sete dias de doses, e a dose
     *            das 20h não está atrasada às 10h.
     * Parâmetros (IN):
     *   p_medication_id  medicação
     *   p_de, p_ate      período; o fim é limitado a agora
     * Retorno  : NUMBER >= 0, ou NULL se a medicação não existe.
     * Exceções : NO_DATA_FOUND -> NULL; falha inesperada -> LOG_ERRO_PLSQL e relança.
     * Exemplo  : SELECT name, pkg_medicacao.doses_esperadas(id, SYSTIMESTAMP - 7, SYSTIMESTAMP) FROM medications;
     */
    FUNCTION doses_esperadas (
        p_medication_id IN RAW,
        p_de            IN TIMESTAMP WITH TIME ZONE,
        p_ate           IN TIMESTAMP WITH TIME ZONE
    ) RETURN NUMBER;

    /*
     * TAXA_ADESAO: o indicador
     * Objetivo : % de doses confirmadas sobre as doses esperadas pela rotina declarada de remédios.
     *            Esperadas = horários do schedule (JSON) que já venceram na janela, contados por
     *            DOSES_ESPERADAS a partir do dia em que cada medicação começou a ser acompanhada,
     *            só para as medicações acompanhadas pelo app (com ao menos uma confirmação registrada).
     *            Uma medicação que nunca foi marcada no app não é "baixa adesão"; é ausência de dado.
     * Parâmetros (IN):
     *   p_home_id        casa (RAW(16))
     *   p_medication_id  uma medicação específica; NULL = todas as acompanhadas da casa
     *   p_dias           tamanho da janela em dias (padrão 7)
     *   p_ate            fim da janela (padrão: agora)
     * Retorno  : NUMBER entre 0 e 100 com uma casa decimal, ou NULL quando não há dado.
     *            Casa sem dados devolve NULL, nunca erro.
     * Exceções : janela inválida -> ORA-20002; falha inesperada -> registrada em LOG_ERRO_PLSQL e
     *            relançada.
     * Exemplo  : SELECT patient_name, pkg_medicacao.taxa_adesao(id, NULL, 7) AS adesao_7d FROM homes;
     */
    FUNCTION taxa_adesao (
        p_home_id       IN RAW,
        p_medication_id IN RAW DEFAULT NULL,
        p_dias          IN NUMBER DEFAULT 7,
        p_ate           IN TIMESTAMP WITH TIME ZONE DEFAULT NULL
    ) RETURN NUMBER;

    /*
     * DOSES_POR_DIA
     * Objetivo : quantos horários a rotina declarada tem por dia (["08:00","20:00"] = 2).
     * Retorno  : NUMBER > 0, ou NULL sem horário.
     * Pura     : não lê tabela nenhuma, por isso a trigger de MEDICATIONS pode chamá-la sem cair no
     *            ORA-04091 (tabela mutante).
     */
    FUNCTION doses_por_dia (p_schedule IN VARCHAR2) RETURN NUMBER DETERMINISTIC;

    /*
     * DIAS_COBERTURA
     * Objetivo : por quantos dias o estoque atual cobre a rotina declarada.
     * Parâmetros (IN): p_estoque_doses, p_schedule (os valores da linha, não o id: ver DOSES_POR_DIA).
     * Retorno  : NUMBER sem arredondar (3,03 dias não é 3), ou NULL sem estoque ou sem horário:
     *            sem dado não se projeta nada.
     * Exemplo  : SELECT name, pkg_medicacao.dias_cobertura(stock_doses, schedule) FROM medications;
     */
    FUNCTION dias_cobertura (p_estoque_doses IN NUMBER, p_schedule IN VARCHAR2) RETURN NUMBER DETERMINISTIC;

END pkg_medicacao;
/

CREATE OR REPLACE PACKAGE BODY pkg_medicacao AS

    FUNCTION doses_esperadas (
        p_medication_id IN RAW,
        p_de            IN TIMESTAMP WITH TIME ZONE,
        p_ate           IN TIMESTAMP WITH TIME ZONE
    ) RETURN NUMBER
    AS
        v_schedule medications.schedule%TYPE;
        v_criada   medications.created_at%TYPE;
        v_primeira TIMESTAMP WITH TIME ZONE;
        v_inicio   TIMESTAMP WITH TIME ZONE;
        v_fim      TIMESTAMP WITH TIME ZONE := LEAST(p_ate, SYSTIMESTAMP);
        v_dia      DATE;
        v_ultimo   DATE;
        v_horario  TIMESTAMP WITH TIME ZONE;
        v_total    NUMBER := 0;
    BEGIN
        SELECT schedule, created_at
          INTO v_schedule, v_criada
          FROM medications
         WHERE id = p_medication_id;

        SELECT MIN(captured_at)
          INTO v_primeira
          FROM signals
         WHERE type = 'ADHERENCE'
           AND JSON_VALUE(signal_value, '$.medicationId') = pkg_apoio.uuid_texto(p_medication_id);

        -- O acompanhamento começa no início do dia (Brasília) do cadastro ou da primeira confirmação.
        v_inicio := FROM_TZ(CAST(TRUNC(CAST(LEAST(v_criada, NVL(v_primeira, v_criada))
                            AT TIME ZONE 'America/Sao_Paulo' AS DATE)) AS TIMESTAMP), 'America/Sao_Paulo');
        v_inicio := GREATEST(v_inicio, p_de);
        IF v_fim <= v_inicio THEN
            RETURN 0;
        END IF;

        -- Um horário por dia, de cada linha do schedule, no relógio de quem toma o remédio.
        v_dia    := TRUNC(CAST(v_inicio AT TIME ZONE 'America/Sao_Paulo' AS DATE));
        v_ultimo := TRUNC(CAST(v_fim AT TIME ZONE 'America/Sao_Paulo' AS DATE));
        WHILE v_dia <= v_ultimo LOOP
            FOR h IN (SELECT hora FROM JSON_TABLE(v_schedule, '$[*]' COLUMNS (hora VARCHAR2(5) PATH '$'))) LOOP
                v_horario := FROM_TZ(CAST(v_dia AS TIMESTAMP)
                                     + NUMTODSINTERVAL(TO_NUMBER(SUBSTR(h.hora, 1, 2)), 'HOUR')
                                     + NUMTODSINTERVAL(TO_NUMBER(SUBSTR(h.hora, 4, 2)), 'MINUTE'),
                                     'America/Sao_Paulo');
                IF v_horario >= v_inicio AND v_horario <= v_fim THEN
                    v_total := v_total + 1;
                END IF;
            END LOOP;
            v_dia := v_dia + 1;
        END LOOP;
        RETURN v_total;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
        WHEN OTHERS THEN
            pkg_apoio.log_erro('PKG_MEDICACAO.DOSES_ESPERADAS', SQLCODE, SQLERRM);
            RAISE;
    END doses_esperadas;

    FUNCTION taxa_adesao (
        p_home_id       IN RAW,
        p_medication_id IN RAW DEFAULT NULL,
        p_dias          IN NUMBER DEFAULT 7,
        p_ate           IN TIMESTAMP WITH TIME ZONE DEFAULT NULL
    ) RETURN NUMBER
    AS
        v_ate          TIMESTAMP WITH TIME ZONE := NVL(p_ate, SYSTIMESTAMP);
        v_desde        TIMESTAMP WITH TIME ZONE;
        v_esperadas    NUMBER;
        v_confirmadas  NUMBER;
    BEGIN
        IF p_dias IS NULL OR p_dias <= 0 THEN
            RAISE_APPLICATION_ERROR(-20002, 'A janela de adesão precisa ter pelo menos 1 dia');
        END IF;
        v_desde := v_ate - NUMTODSINTERVAL(p_dias, 'DAY');

        -- Doses esperadas das medicações acompanhadas, só as que já venceram na janela.
        SELECT NVL(SUM(pkg_medicacao.doses_esperadas(m.id, v_desde, v_ate)), 0)
          INTO v_esperadas
          FROM medications m
         WHERE m.home_id = p_home_id
           AND m.active = 1
           AND (p_medication_id IS NULL OR m.id = p_medication_id)
           AND EXISTS (SELECT 1
                         FROM signals s
                        WHERE s.home_id = m.home_id
                          AND s.type = 'ADHERENCE'
                          AND JSON_VALUE(s.signal_value, '$.medicationId') = pkg_apoio.uuid_texto(m.id));

        IF v_esperadas = 0 THEN
            RETURN NULL;
        END IF;

        SELECT COUNT(*)
          INTO v_confirmadas
          FROM signals s
         WHERE s.home_id = p_home_id
           AND s.type = 'ADHERENCE'
           AND s.captured_at > v_desde
           AND s.captured_at <= v_ate
           AND JSON_VALUE(s.signal_value, '$.taken') = 'true'
           AND JSON_VALUE(s.signal_value, '$.medicationId') IN (
                   SELECT pkg_apoio.uuid_texto(m.id)
                     FROM medications m
                    WHERE m.home_id = p_home_id
                      AND m.active = 1
                      AND (p_medication_id IS NULL OR m.id = p_medication_id));

        -- Teto de 100: dose confirmada fora do horário ainda conta, e não pode virar adesão de 110%.
        RETURN ROUND(LEAST(100, v_confirmadas / v_esperadas * 100), 1);
    EXCEPTION
        WHEN NO_DATA_FOUND OR ZERO_DIVIDE THEN
            RETURN NULL;
        WHEN OTHERS THEN
            IF SQLCODE = -20002 THEN
                RAISE;
            END IF;
            pkg_apoio.log_erro('PKG_MEDICACAO.TAXA_ADESAO', SQLCODE, SQLERRM);
            RAISE;
    END taxa_adesao;

    FUNCTION doses_por_dia (p_schedule IN VARCHAR2) RETURN NUMBER DETERMINISTIC
    AS
        v_doses NUMBER;
    BEGIN
        IF p_schedule IS NULL THEN
            RETURN NULL;
        END IF;
        SELECT COUNT(*)
          INTO v_doses
          FROM JSON_TABLE(p_schedule, '$[*]' COLUMNS (hora VARCHAR2(5) PATH '$'));
        RETURN NULLIF(v_doses, 0);
    EXCEPTION
        WHEN OTHERS THEN
            pkg_apoio.log_erro('PKG_MEDICACAO.DOSES_POR_DIA', SQLCODE, SQLERRM);
            RAISE;
    END doses_por_dia;

    FUNCTION dias_cobertura (p_estoque_doses IN NUMBER, p_schedule IN VARCHAR2) RETURN NUMBER DETERMINISTIC
    AS
    BEGIN
        -- NULL / NULL e estoque / NULL dão NULL: sem estoque ou sem horário não há projeção.
        RETURN p_estoque_doses / doses_por_dia(p_schedule);
    END dias_cobertura;

END pkg_medicacao;
/
