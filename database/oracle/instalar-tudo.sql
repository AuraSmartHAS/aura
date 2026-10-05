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


PROMPT == V1__esquema_aura.sql ==
-- Esquema físico do AURA no Oracle (Fase 6).
--
-- Mesmas 12 tabelas do baseline PostgreSQL, com os tipos que o Hibernate 6.5 espera no Oracle
-- (o perfil oracle sobe com ddl-auto: validate, então qualquer divergência derruba o boot):
--   UUID    -> RAW(16)            (o Oracle não tem tipo UUID; SYS_GUID() também devolve RAW(16))
--   Instant -> TIMESTAMP(6) WITH TIME ZONE
--   boolean -> NUMBER(1) com CHECK (0,1). Não usamos o BOOLEAN do 23ai: o servidor da FIAP pode
--              ser 19c e o Hibernate 6.5 continua mapeando boolean para NUMBER(1).
--   double  -> FLOAT(53)          String -> VARCHAR2(n CHAR)
--
-- Diferença deliberada em relação ao PostgreSQL: aqui as chaves estrangeiras existem. O modelo
-- relacional é o que o DER documenta, e o banco passa a recusar órfão por conta própria. A regra
-- de apagamento foi pensada caso a caso:
--   * home_id -> HOMES ............ NO ACTION. O LgpdService apaga os filhos antes da casa; a FK
--                                   só garante que ninguém pule essa ordem.
--   * medication_id, *_by_user_id . SET NULL. A recomendação de refil e o registro de SOS
--                                   sobrevivem à exclusão da medicação ou da conta de quem agiu.
--   * sku -> PRODUCTS ............. NO ACTION. Produto com histórico não some do catálogo; o Java
--                                   responde 409 antes de tentar (CatalogService.delete).
-- Os mesmos três casos também são tratados no Java, para valerem em H2 e PostgreSQL.
--
-- Enums continuam sem CHECK de valores, pelo motivo documentado em HomeMemberRole.java: um valor
-- novo no Java não pode depender de alterar constraint no banco.

CREATE TABLE users (
    id              RAW(16)                     NOT NULL,
    email           VARCHAR2(255 CHAR)          NOT NULL,
    password_hash   VARCHAR2(255 CHAR)          NOT NULL,
    role            VARCHAR2(255 CHAR)          NOT NULL,
    name            VARCHAR2(255 CHAR),
    fcm_token       VARCHAR2(255 CHAR),
    created_at      TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    CONSTRAINT pk_users PRIMARY KEY (id),
    CONSTRAINT uk_users_email UNIQUE (email)
);

CREATE TABLE homes (
    id               RAW(16)                     NOT NULL,
    owner_user_id    RAW(16)                     NOT NULL,
    patient_name     VARCHAR2(255 CHAR)          NOT NULL,
    birth_date       DATE,
    label            VARCHAR2(255 CHAR),
    cep              VARCHAR2(255 CHAR),
    address          VARCHAR2(255 CHAR),
    lat              FLOAT(53),
    lng              FLOAT(53),
    safety_checklist VARCHAR2(2000 CHAR),
    created_at       TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    CONSTRAINT pk_homes PRIMARY KEY (id),
    CONSTRAINT fk_homes_owner FOREIGN KEY (owner_user_id) REFERENCES users (id),
    CONSTRAINT ck_homes_checklist_json CHECK (safety_checklist IS JSON)
);
CREATE INDEX idx_homes_owner_user_id ON homes (owner_user_id);

CREATE TABLE home_members (
    id         RAW(16)                     NOT NULL,
    home_id    RAW(16)                     NOT NULL,
    user_id    RAW(16)                     NOT NULL,
    role       VARCHAR2(20 CHAR)           NOT NULL,
    created_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    CONSTRAINT pk_home_members PRIMARY KEY (id),
    CONSTRAINT uk_home_members_home_user UNIQUE (home_id, user_id),
    CONSTRAINT fk_home_members_home FOREIGN KEY (home_id) REFERENCES homes (id),
    CONSTRAINT fk_home_members_user FOREIGN KEY (user_id) REFERENCES users (id)
);
CREATE INDEX idx_home_members_user_id ON home_members (user_id);

CREATE TABLE consents (
    id          RAW(16)                     NOT NULL,
    user_id     RAW(16)                     NOT NULL,
    version     VARCHAR2(255 CHAR)          NOT NULL,
    accepted_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    CONSTRAINT pk_consents PRIMARY KEY (id),
    CONSTRAINT fk_consents_user FOREIGN KEY (user_id) REFERENCES users (id)
);
CREATE INDEX idx_consents_user_id ON consents (user_id);

CREATE TABLE signals (
    id           RAW(16)                     NOT NULL,
    home_id      RAW(16)                     NOT NULL,
    type         VARCHAR2(255 CHAR)          NOT NULL,
    source       VARCHAR2(255 CHAR)          NOT NULL,
    signal_value VARCHAR2(2000 CHAR),
    captured_at  TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    CONSTRAINT pk_signals PRIMARY KEY (id),
    CONSTRAINT fk_signals_home FOREIGN KEY (home_id) REFERENCES homes (id),
    CONSTRAINT ck_signals_value_json CHECK (signal_value IS JSON)
);
CREATE INDEX idx_signals_home_captured ON signals (home_id, captured_at);

CREATE TABLE scores (
    id             RAW(16)                     NOT NULL,
    home_id        RAW(16)                     NOT NULL,
    dimension      VARCHAR2(255 CHAR)          NOT NULL,
    factors        VARCHAR2(1000 CHAR),
    weights        VARCHAR2(500 CHAR),
    score_value    FLOAT(53)                   NOT NULL,
    risk_level     VARCHAR2(255 CHAR)          NOT NULL,
    explanation    VARCHAR2(1000 CHAR),
    config_version VARCHAR2(255 CHAR),
    explained_at   TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    CONSTRAINT pk_scores PRIMARY KEY (id),
    CONSTRAINT fk_scores_home FOREIGN KEY (home_id) REFERENCES homes (id),
    CONSTRAINT ck_scores_value CHECK (score_value BETWEEN 0 AND 1)
);
CREATE INDEX idx_scores_home_explained ON scores (home_id, explained_at);

CREATE TABLE products (
    sku          VARCHAR2(255 CHAR) NOT NULL,
    name         VARCHAR2(255 CHAR) NOT NULL,
    category     VARCHAR2(255 CHAR) NOT NULL,
    price        NUMBER(10,2)       NOT NULL,
    installable  NUMBER(1)          NOT NULL,
    norm_ref     VARCHAR2(255 CHAR),
    risk_tag     VARCHAR2(255 CHAR),
    featured     NUMBER(1)          NOT NULL,
    partner      VARCHAR2(255 CHAR),
    product_url  VARCHAR2(500 CHAR),
    stock_nearby NUMBER(10)         NOT NULL,
    CONSTRAINT pk_products PRIMARY KEY (sku),
    CONSTRAINT ck_products_installable CHECK (installable IN (0, 1)),
    CONSTRAINT ck_products_featured CHECK (featured IN (0, 1)),
    CONSTRAINT ck_products_price CHECK (price >= 0)
);
CREATE INDEX idx_products_category ON products (category);
CREATE INDEX idx_products_partner ON products (partner);

CREATE TABLE stock_nodes (
    id   RAW(16)            NOT NULL,
    name VARCHAR2(255 CHAR),
    type VARCHAR2(255 CHAR),
    lat  FLOAT(53)          NOT NULL,
    lng  FLOAT(53)          NOT NULL,
    CONSTRAINT pk_stock_nodes PRIMARY KEY (id)
);

CREATE TABLE medications (
    id          RAW(16)                     NOT NULL,
    home_id     RAW(16)                     NOT NULL,
    name        VARCHAR2(255 CHAR)          NOT NULL,
    dosage      VARCHAR2(255 CHAR),
    schedule    VARCHAR2(500 CHAR),
    notes       VARCHAR2(500 CHAR),
    stock_doses NUMBER(10),
    active      NUMBER(1)                   NOT NULL,
    created_at  TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    CONSTRAINT pk_medications PRIMARY KEY (id),
    CONSTRAINT fk_medications_home FOREIGN KEY (home_id) REFERENCES homes (id),
    CONSTRAINT ck_medications_active CHECK (active IN (0, 1)),
    CONSTRAINT ck_medications_schedule_json CHECK (schedule IS JSON),
    CONSTRAINT ck_medications_stock CHECK (stock_doses >= 0)
);
CREATE INDEX idx_medications_home_id ON medications (home_id);

CREATE TABLE recommendations (
    id            RAW(16)                     NOT NULL,
    home_id       RAW(16)                     NOT NULL,
    score_id      RAW(16),
    medication_id RAW(16),
    sku           VARCHAR2(255 CHAR)          NOT NULL,
    reason        VARCHAR2(500 CHAR)          NOT NULL,
    status        VARCHAR2(255 CHAR)          NOT NULL,
    factors       VARCHAR2(1000 CHAR),
    weights       VARCHAR2(500 CHAR),
    created_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    CONSTRAINT pk_recommendations PRIMARY KEY (id),
    CONSTRAINT fk_recommendations_home FOREIGN KEY (home_id) REFERENCES homes (id),
    CONSTRAINT fk_recommendations_score FOREIGN KEY (score_id) REFERENCES scores (id),
    CONSTRAINT fk_recommendations_medication FOREIGN KEY (medication_id)
        REFERENCES medications (id) ON DELETE SET NULL,
    CONSTRAINT fk_recommendations_product FOREIGN KEY (sku) REFERENCES products (sku)
);
CREATE INDEX idx_recommendations_home_id ON recommendations (home_id);
-- Toda FK que o Oracle confere numa exclusão do pai precisa de índice no filho; sem ele, apagar
-- uma medicação ou um produto trava a tabela filha inteira enquanto procura referências.
CREATE INDEX idx_recommendations_medication ON recommendations (medication_id);
CREATE INDEX idx_recommendations_sku ON recommendations (sku);

CREATE TABLE orders (
    id                RAW(16)                     NOT NULL,
    home_id           RAW(16)                     NOT NULL,
    recommendation_id RAW(16)                     NOT NULL,
    sku               VARCHAR2(255 CHAR)          NOT NULL,
    stage             VARCHAR2(255 CHAR)          NOT NULL,
    node_name         VARCHAR2(255 CHAR),
    distance_m        NUMBER(10),
    sla_due_at        TIMESTAMP(6) WITH TIME ZONE,
    sla_breached      NUMBER(1)                   NOT NULL,
    eta_delivery      TIMESTAMP(6) WITH TIME ZONE,
    delivered_at      TIMESTAMP(6) WITH TIME ZONE,
    install_at        TIMESTAMP(6) WITH TIME ZONE,
    installed_at      TIMESTAMP(6) WITH TIME ZONE,
    created_at        TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    CONSTRAINT pk_orders PRIMARY KEY (id),
    CONSTRAINT fk_orders_home FOREIGN KEY (home_id) REFERENCES homes (id),
    CONSTRAINT fk_orders_recommendation FOREIGN KEY (recommendation_id) REFERENCES recommendations (id),
    CONSTRAINT fk_orders_product FOREIGN KEY (sku) REFERENCES products (sku),
    CONSTRAINT ck_orders_sla_breached CHECK (sla_breached IN (0, 1))
);
CREATE INDEX idx_orders_home_id ON orders (home_id);
CREATE INDEX idx_orders_recommendation ON orders (recommendation_id);
CREATE INDEX idx_orders_sku ON orders (sku);

CREATE TABLE emergencies (
    id                      RAW(16)                     NOT NULL,
    home_id                 RAW(16)                     NOT NULL,
    triggered_by_user_id    RAW(16),
    channel                 VARCHAR2(20 CHAR)           NOT NULL,
    state                   VARCHAR2(30 CHAR)           NOT NULL,
    created_at              TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    dispatch_due_at         TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    dispatched_at           TIMESTAMP(6) WITH TIME ZONE,
    escalate_due_at         TIMESTAMP(6) WITH TIME ZONE,
    escalated_at            TIMESTAMP(6) WITH TIME ZONE,
    cancelled_at            TIMESTAMP(6) WITH TIME ZONE,
    acknowledged_at         TIMESTAMP(6) WITH TIME ZONE,
    acknowledged_by_user_id RAW(16),
    state_changed_at        TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    transport_real          NUMBER(1)                   NOT NULL,
    notified_count          NUMBER(10)                  NOT NULL,
    escalated_count         NUMBER(10)                  NOT NULL,
    retraction_sent         NUMBER(1)                   NOT NULL,
    lat                     FLOAT(53),
    lng                     FLOAT(53),
    CONSTRAINT pk_emergencies PRIMARY KEY (id),
    CONSTRAINT fk_emergencies_home FOREIGN KEY (home_id) REFERENCES homes (id),
    CONSTRAINT fk_emergencies_triggered_by FOREIGN KEY (triggered_by_user_id)
        REFERENCES users (id) ON DELETE SET NULL,
    CONSTRAINT fk_emergencies_ack_by FOREIGN KEY (acknowledged_by_user_id)
        REFERENCES users (id) ON DELETE SET NULL,
    CONSTRAINT ck_emergencies_transport CHECK (transport_real IN (0, 1)),
    CONSTRAINT ck_emergencies_retraction CHECK (retraction_sent IN (0, 1))
);
CREATE INDEX idx_emergencies_home_created ON emergencies (home_id, created_at);
CREATE INDEX idx_emergencies_triggered_by ON emergencies (triggered_by_user_id);
CREATE INDEX idx_emergencies_ack_by ON emergencies (acknowledged_by_user_id);

-- Dicionário de dados: o que o DER e o SQL Developer mostram ao lado de cada tabela.
COMMENT ON TABLE users IS 'Contas de acesso: cuidadora, paciente, profissional e administrador';
COMMENT ON TABLE homes IS 'Casa acompanhada, com o checklist de segurança respondido no cadastro';
COMMENT ON TABLE home_members IS 'Vínculo pessoa-casa e o papel de cada um (dono, cuidadora, paciente)';
COMMENT ON TABLE consents IS 'Aceite do termo LGPD por versão; sem ele não se grava dado de saúde';
COMMENT ON TABLE signals IS 'Leituras da casa: voz, autorrelato, uso do app e pulseira. Nunca sensor instalado';
COMMENT ON TABLE scores IS 'Escore de risco explicável por dimensão, com fatores e pesos versionados';
COMMENT ON TABLE products IS 'Catálogo multi-fornecedor; o preço é de referência do parceiro';
COMMENT ON TABLE stock_nodes IS 'Lojas e centros de distribuição usados para escolher a origem mais próxima';
COMMENT ON TABLE medications IS 'Medicações da casa, horários (JSON) e doses em estoque';
COMMENT ON TABLE recommendations IS 'Item sugerido à cuidadora, com o motivo; só vira pedido com aprovação humana';
COMMENT ON TABLE orders IS 'Demanda aprovada e encaminhada ao parceiro';
COMMENT ON TABLE emergencies IS 'Pedidos de socorro (SOS) e o ciclo de aviso, escalonamento e confirmação';
COMMENT ON COLUMN signals.signal_value IS 'JSON da leitura, ex.: {"event":"near_fall","place":"bathroom"}';
COMMENT ON COLUMN medications.schedule IS 'Horários em JSON, ex.: ["08:00","14:00","20:00"]';
COMMENT ON COLUMN scores.risk_level IS 'LOW, MEDIUM ou HIGH; renomeada de LEVEL, que é palavra reservada no Oracle';


PROMPT == V2__inteligencia_cuidado.sql ==
-- Camada de inteligência do cuidado (Fase 6): o banco deixa de ser só depósito.
--
-- Quatro tabelas que existem só no Oracle, porque são escritas e lidas pelo PL/SQL:
--   REGRA_ALERTA      limiares versionados, no mesmo espírito do scoring-weights.yml
--                     ("nenhum limiar escondido no código")
--   ALERTA            avisos que PRC_REGISTRAR_ALERTAS grava a cada leitura nova
--   INDICADOR_DIARIO  fotografia diária por casa, consolidada por PRC_CONSOLIDAR_INDICADORES
--   LOG_ERRO_PLSQL    falhas das rotinas, gravadas em transação autônoma
--
-- LGPD: ALERTA e INDICADOR_DIARIO são dado derivado da casa, então saem junto com ela
-- (ON DELETE CASCADE). LOG_ERRO_PLSQL não guarda casa nem dado de saúde, só a rotina e o erro.
-- Os limiares comparam a pessoa com ela mesma ou com a rotina declarada de remédios; nenhum é
-- faixa clínica, e nenhuma mensagem orienta dose ou diagnóstico.

CREATE TABLE regra_alerta (
    codigo        VARCHAR2(30 CHAR)  NOT NULL,
    descricao     VARCHAR2(200 CHAR) NOT NULL,
    severidade    VARCHAR2(10 CHAR)  NOT NULL,
    limiar        NUMBER(8,2)        NOT NULL,
    janela_horas  NUMBER(5)          NOT NULL,
    ativa         NUMBER(1)          DEFAULT 1 NOT NULL,
    versao        VARCHAR2(20 CHAR)  NOT NULL,
    CONSTRAINT pk_regra_alerta PRIMARY KEY (codigo),
    CONSTRAINT ck_regra_alerta_severidade CHECK (severidade IN ('info', 'atencao', 'alta')),
    CONSTRAINT ck_regra_alerta_ativa CHECK (ativa IN (0, 1)),
    CONSTRAINT ck_regra_alerta_janela CHECK (janela_horas > 0)
);

CREATE TABLE alerta (
    id           RAW(16)                     DEFAULT SYS_GUID() NOT NULL,
    home_id      RAW(16)                     NOT NULL,
    regra        VARCHAR2(30 CHAR)           NOT NULL,
    severidade   VARCHAR2(10 CHAR)           NOT NULL,
    mensagem     VARCHAR2(400 CHAR)          NOT NULL,
    signal_id    RAW(16),
    -- O que torna o aviso único dentro da regra: o id da leitura (quase-queda) ou o dia
    -- (regras de janela). É o que deixa a procedure idempotente: rodar de novo não duplica.
    chave_dedup  VARCHAR2(64 CHAR)           NOT NULL,
    status       VARCHAR2(10 CHAR)           DEFAULT 'aberto' NOT NULL,
    criado_em    TIMESTAMP(6) WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    visto_em     TIMESTAMP(6) WITH TIME ZONE,
    CONSTRAINT pk_alerta PRIMARY KEY (id),
    CONSTRAINT uk_alerta_dedup UNIQUE (home_id, regra, chave_dedup),
    CONSTRAINT fk_alerta_home FOREIGN KEY (home_id) REFERENCES homes (id) ON DELETE CASCADE,
    CONSTRAINT fk_alerta_regra FOREIGN KEY (regra) REFERENCES regra_alerta (codigo),
    -- SET NULL: o LgpdService apaga as leituras antes da casa; o aviso não pode travar isso.
    CONSTRAINT fk_alerta_signal FOREIGN KEY (signal_id) REFERENCES signals (id) ON DELETE SET NULL,
    CONSTRAINT ck_alerta_severidade CHECK (severidade IN ('info', 'atencao', 'alta')),
    CONSTRAINT ck_alerta_status CHECK (status IN ('aberto', 'visto'))
);
CREATE INDEX idx_alerta_home_criado ON alerta (home_id, criado_em);
CREATE INDEX idx_alerta_signal ON alerta (signal_id);
CREATE INDEX idx_alerta_regra ON alerta (regra);

CREATE TABLE indicador_diario (
    home_id             RAW(16)                     NOT NULL,
    data_ref            DATE                        NOT NULL,
    adesao_pct          NUMBER(5,1),
    variacao_passos_pct NUMBER(6,1),
    alertas_abertos     NUMBER(5)                   NOT NULL,
    quase_quedas        NUMBER(5)                   NOT NULL,
    atualizado_em       TIMESTAMP(6) WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_indicador_diario PRIMARY KEY (home_id, data_ref),
    CONSTRAINT fk_indicador_home FOREIGN KEY (home_id) REFERENCES homes (id) ON DELETE CASCADE
);

CREATE TABLE log_erro_plsql (
    id            NUMBER GENERATED ALWAYS AS IDENTITY,
    origem        VARCHAR2(60 CHAR)           NOT NULL,
    codigo        NUMBER(10),
    mensagem      VARCHAR2(1000 CHAR),
    registrado_em TIMESTAMP(6) WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_log_erro_plsql PRIMARY KEY (id)
);

-- Regras da versão 2026-10. Uma linha por INSERT, sem VALUES de várias linhas (sintaxe só do 23ai).
INSERT INTO regra_alerta (codigo, descricao, severidade, limiar, janela_horas, ativa, versao)
VALUES ('QUASE_QUEDA', 'Quase-queda registrada pela família ou pela voz', 'alta', 1, 48, 1, '2026-10');
INSERT INTO regra_alerta (codigo, descricao, severidade, limiar, janela_horas, ativa, versao)
VALUES ('DOSES_NEGADAS', 'Doses marcadas como não confirmadas na janela', 'atencao', 2, 48, 1, '2026-10');
INSERT INTO regra_alerta (codigo, descricao, severidade, limiar, janela_horas, ativa, versao)
VALUES ('ADESAO_BAIXA', 'Adesão abaixo do limiar (%) nos últimos dias, pelas doses confirmadas no app', 'atencao', 80, 168, 1, '2026-10');
INSERT INTO regra_alerta (codigo, descricao, severidade, limiar, janela_horas, ativa, versao)
VALUES ('ROTINA_PASSOS', 'Passos abaixo da rotina da própria pessoa (% de queda contra a linha de base)', 'info', 30, 72, 1, '2026-10');

COMMENT ON TABLE regra_alerta IS 'Limiares versionados das regras de aviso; mudar um limiar é um UPDATE auditável, não um deploy';
COMMENT ON TABLE alerta IS 'Avisos gravados pelo banco a cada leitura nova (PRC_REGISTRAR_ALERTAS)';
COMMENT ON TABLE indicador_diario IS 'Indicadores diários por casa, consolidados por PRC_CONSOLIDAR_INDICADORES';
COMMENT ON TABLE log_erro_plsql IS 'Falhas das rotinas PL/SQL, gravadas em transação autônoma; sem dado de saúde';
COMMENT ON COLUMN alerta.regra IS 'Código da regra de REGRA_ALERTA que disparou o aviso';
COMMENT ON COLUMN alerta.chave_dedup IS 'Id da leitura ou dia (AAAAMMDD): impede aviso duplicado da mesma regra';


PROMPT == R__01_apoio.sql ==
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


PROMPT == R__02_functions.sql ==
-- Functions do AURA: indicadores calculados no banco e texto pronto para a tela.
-- Todas recebem só parâmetros IN, devolvem um valor (RETURN) e tratam as próprias exceções.
-- A autorização (quem pode ver qual casa) é do Java, antes da chamada: o PL/SQL recebe só o id.

/*
 * FN_TAXA_ADESAO — o indicador
 * Objetivo : % de doses confirmadas sobre as doses esperadas pela rotina declarada de remédios.
 *            Esperadas = horários do schedule (JSON) × dias da janela, só para as medicações
 *            acompanhadas pelo app (com ao menos uma confirmação registrada). Uma medicação que
 *            nunca foi marcada no app não é "baixa adesão"; é ausência de dado.
 * Parâmetros (IN):
 *   p_home_id        casa (RAW(16))
 *   p_medication_id  uma medicação específica; NULL = todas as acompanhadas da casa
 *   p_dias           tamanho da janela em dias (padrão 7)
 *   p_ate            fim da janela (padrão: agora)
 * Retorno  : NUMBER entre 0 e 100 com uma casa decimal, ou NULL quando não há dado.
 *            Casa sem dados devolve NULL, nunca erro.
 * Exceções : janela inválida -> ORA-20002; falha inesperada -> registrada em LOG_ERRO_PLSQL e
 *            relançada.
 * Exemplo  : SELECT patient_name, fn_taxa_adesao(id, NULL, 7) AS adesao_7d FROM homes;
 */
CREATE OR REPLACE FUNCTION fn_taxa_adesao (
    p_home_id       IN RAW,
    p_medication_id IN RAW DEFAULT NULL,
    p_dias          IN NUMBER DEFAULT 7,
    p_ate           IN TIMESTAMP WITH TIME ZONE DEFAULT NULL
) RETURN NUMBER
AS
    v_ate          TIMESTAMP WITH TIME ZONE := NVL(p_ate, SYSTIMESTAMP);
    v_desde        TIMESTAMP WITH TIME ZONE;
    v_doses_dia    NUMBER;
    v_esperadas    NUMBER;
    v_confirmadas  NUMBER;
BEGIN
    IF p_dias IS NULL OR p_dias <= 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'A janela de adesão precisa ter pelo menos 1 dia');
    END IF;
    v_desde := v_ate - NUMTODSINTERVAL(p_dias, 'DAY');

    -- Doses por dia das medicações acompanhadas: uma linha por horário do schedule.
    SELECT COUNT(*)
      INTO v_doses_dia
      FROM medications m,
           JSON_TABLE(m.schedule, '$[*]' COLUMNS (hora VARCHAR2(5) PATH '$')) h
     WHERE m.home_id = p_home_id
       AND m.active = 1
       AND (p_medication_id IS NULL OR m.id = p_medication_id)
       AND EXISTS (SELECT 1
                     FROM signals s
                    WHERE s.home_id = m.home_id
                      AND s.type = 'ADHERENCE'
                      AND JSON_VALUE(s.signal_value, '$.medicationId') = fn_uuid_texto(m.id));

    v_esperadas := v_doses_dia * p_dias;
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
               SELECT fn_uuid_texto(m.id)
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
        prc_log_erro('FN_TAXA_ADESAO', SQLCODE, SQLERRM);
        RAISE;
END fn_taxa_adesao;
/

/*
 * FN_DESCREVER_LEITURA — dado formatado
 * Objetivo : transformar uma leitura crua (tipo + JSON) numa frase que a família entende,
 *            no formato "o quê · onde · como · quando". É o texto dos avisos e das consultas.
 *            Exemplos: "Quase-queda registrada · banheiro · por voz · 04/10 14:32"
 *                      "Pulseira: 1.800 passos · sono 5,6 h · FC em repouso 79 bpm · 04/10 08:00"
 * Parâmetro: p_signal_id (IN) id da leitura em SIGNALS.
 * Retorno  : VARCHAR2 (até 300 caracteres), horário de Brasília.
 * Exceções : leitura inexistente -> 'Leitura não encontrada'; qualquer outra falha devolve o tipo
 *            cru, para nunca derrubar a lista de avisos por causa de um JSON inesperado.
 * Guardrail: o texto descreve o que foi observado. Nunca orienta dose ("tomar") nem diagnostica.
 */
CREATE OR REPLACE FUNCTION fn_descrever_leitura (p_signal_id IN RAW) RETURN VARCHAR2
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
    c_nls      CONSTANT VARCHAR2(40) := 'NLS_NUMERIC_CHARACTERS = '',.''';

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
             WHERE fn_uuid_texto(m.id) = JSON_VALUE(v_json, '$.medicationId');
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
        prc_log_erro('FN_DESCREVER_LEITURA', SQLCODE, SQLERRM);
        RETURN NVL(INITCAP(v_tipo), 'Leitura');
END fn_descrever_leitura;
/

/*
 * FN_VARIACAO_ROTINA — mudança de rotina percebida pela pulseira
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
 * Exemplo  : SELECT fn_variacao_rotina(id, 'steps') FROM homes;
 */
CREATE OR REPLACE FUNCTION fn_variacao_rotina (
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
    IF p_metrica NOT IN ('steps', 'sleepHours', 'restingHeartRate') THEN
        RAISE_APPLICATION_ERROR(-20003, 'Métrica da pulseira desconhecida: ' || p_metrica);
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
        prc_log_erro('FN_VARIACAO_ROTINA', SQLCODE, SQLERRM);
        RAISE;
END fn_variacao_rotina;
/


PROMPT == R__03_procedures.sql ==
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
            SELECT COUNT(*)
              INTO v_valor
              FROM signals
             WHERE home_id = p_home_id
               AND type = 'ADHERENCE'
               AND JSON_VALUE(signal_value, '$.taken') = 'false'
               AND captured_at > v_desde
               AND captured_at <= SYSTIMESTAMP;
            IF v_valor >= r.limiar THEN
                registrar(r.codigo, r.severidade,
                          v_valor || ' doses não confirmadas nas últimas ' || v_janela || ' h',
                          v_hoje);
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
               (SELECT COUNT(*)
                  FROM JSON_TABLE(m.schedule, '$[*]' COLUMNS (hora VARCHAR2(5) PATH '$'))) * v_dias
                   AS doses_esperadas,
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


PROMPT == Conferência: objetos inválidos (o esperado é nenhum) ==
SELECT object_type, object_name FROM user_objects WHERE status = 'INVALID';

COMMIT;
PROMPT == Instalação concluída ==
