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
