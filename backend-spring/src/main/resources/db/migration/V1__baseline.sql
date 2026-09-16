-- Baseline do schema que o Hibernate vinha criando sozinho com ddl-auto.
-- A partir daqui o perfil postgres roda com ddl-auto: validate — se este arquivo divergir das
-- entidades, o boot falha em vez de o schema derivar em silêncio entre uma subida e outra.
--
-- Sem check constraint de enum, de propósito: o motivo está em HomeMemberRole.java e vale para
-- todos os enums do projeto. ddl-auto: update cria tabela nova mas nunca altera check existente,
-- então um papel novo quebraria em PostgreSQL passando verde no H2, que recria o schema a cada boot.
--
-- ponytail: sem foreign key. As entidades guardam UUID solto, não @ManyToOne, então o Hibernate
-- nunca gerou FK aqui e `validate` também não as exige. Criar FK agora quebraria a exclusão de casa
-- (D-006) sem um ON DELETE pensado caso a caso. Os índices abaixo cobrem o que a demo consulta.
-- Se a exclusão em cascata virar requisito, aí sim vale adicionar FK com a regra de apagamento.

CREATE TABLE users (
    id              uuid PRIMARY KEY,
    email           varchar(255) NOT NULL,
    password_hash   varchar(255) NOT NULL,
    role            varchar(255) NOT NULL,
    name            varchar(255),
    fcm_token       varchar(255),
    created_at      timestamp(6) with time zone NOT NULL,
    CONSTRAINT uk_users_email UNIQUE (email)
);

CREATE TABLE homes (
    id               uuid PRIMARY KEY,
    owner_user_id    uuid NOT NULL,
    patient_name     varchar(255) NOT NULL,
    birth_date       date,
    label            varchar(255),
    cep              varchar(255),
    address          varchar(255),
    lat              float8,
    lng              float8,
    safety_checklist varchar(2000),
    created_at       timestamp(6) with time zone NOT NULL
);
CREATE INDEX idx_homes_owner_user_id ON homes (owner_user_id);

CREATE TABLE home_members (
    id         uuid PRIMARY KEY,
    home_id    uuid NOT NULL,
    user_id    uuid NOT NULL,
    role       varchar(20) NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT uk_home_members_home_user UNIQUE (home_id, user_id)
);
CREATE INDEX idx_home_members_user_id ON home_members (user_id);

CREATE TABLE consents (
    id          uuid PRIMARY KEY,
    user_id     uuid NOT NULL,
    version     varchar(255) NOT NULL,
    accepted_at timestamp(6) with time zone NOT NULL
);
CREATE INDEX idx_consents_user_id ON consents (user_id);

CREATE TABLE signals (
    id           uuid PRIMARY KEY,
    home_id      uuid NOT NULL,
    type         varchar(255) NOT NULL,
    source       varchar(255) NOT NULL,
    signal_value varchar(2000),
    captured_at  timestamp(6) with time zone NOT NULL
);
CREATE INDEX idx_signals_home_captured ON signals (home_id, captured_at);

CREATE TABLE scores (
    id             uuid PRIMARY KEY,
    home_id        uuid NOT NULL,
    dimension      varchar(255) NOT NULL,
    factors        varchar(1000),
    weights        varchar(500),
    score_value    float8 NOT NULL,
    level          varchar(255) NOT NULL,
    explanation    varchar(1000),
    config_version varchar(255),
    explained_at   timestamp(6) with time zone NOT NULL
);
CREATE INDEX idx_scores_home_explained ON scores (home_id, explained_at);

CREATE TABLE products (
    sku          varchar(255) PRIMARY KEY,
    name         varchar(255) NOT NULL,
    category     varchar(255) NOT NULL,
    price        numeric(10,2) NOT NULL,
    installable  boolean NOT NULL,
    norm_ref     varchar(255),
    risk_tag     varchar(255),
    featured     boolean NOT NULL,
    stock_nearby integer NOT NULL
);
CREATE INDEX idx_products_category ON products (category);

CREATE TABLE stock_nodes (
    id   uuid PRIMARY KEY,
    name varchar(255),
    type varchar(255),
    lat  float8 NOT NULL,
    lng  float8 NOT NULL
);

CREATE TABLE medications (
    id          uuid PRIMARY KEY,
    home_id     uuid NOT NULL,
    name        varchar(255) NOT NULL,
    dosage      varchar(255),
    schedule    varchar(500),
    notes       varchar(500),
    stock_doses integer,
    active      boolean NOT NULL,
    created_at  timestamp(6) with time zone NOT NULL
);
CREATE INDEX idx_medications_home_id ON medications (home_id);

CREATE TABLE recommendations (
    id            uuid PRIMARY KEY,
    home_id       uuid NOT NULL,
    score_id      uuid,
    medication_id uuid,
    sku           varchar(255) NOT NULL,
    reason        varchar(500) NOT NULL,
    status        varchar(255) NOT NULL,
    factors       varchar(1000),
    weights       varchar(500),
    created_at    timestamp(6) with time zone NOT NULL
);
CREATE INDEX idx_recommendations_home_id ON recommendations (home_id);

CREATE TABLE orders (
    id                uuid PRIMARY KEY,
    home_id           uuid NOT NULL,
    recommendation_id uuid NOT NULL,
    sku               varchar(255) NOT NULL,
    stage             varchar(255) NOT NULL,
    node_name         varchar(255),
    distance_m        integer,
    sla_due_at        timestamp(6) with time zone,
    sla_breached      boolean NOT NULL,
    eta_delivery      timestamp(6) with time zone,
    delivered_at      timestamp(6) with time zone,
    install_at        timestamp(6) with time zone,
    installed_at      timestamp(6) with time zone,
    created_at        timestamp(6) with time zone NOT NULL
);
CREATE INDEX idx_orders_home_id ON orders (home_id);

CREATE TABLE emergencies (
    id                      uuid PRIMARY KEY,
    home_id                 uuid NOT NULL,
    triggered_by_user_id    uuid,
    channel                 varchar(20) NOT NULL,
    state                   varchar(30) NOT NULL,
    created_at              timestamp(6) with time zone NOT NULL,
    dispatch_due_at         timestamp(6) with time zone NOT NULL,
    dispatched_at           timestamp(6) with time zone,
    escalate_due_at         timestamp(6) with time zone,
    escalated_at            timestamp(6) with time zone,
    cancelled_at            timestamp(6) with time zone,
    acknowledged_at         timestamp(6) with time zone,
    acknowledged_by_user_id uuid,
    state_changed_at        timestamp(6) with time zone NOT NULL,
    transport_real          boolean NOT NULL,
    notified_count          integer NOT NULL,
    escalated_count         integer NOT NULL,
    retraction_sent         boolean NOT NULL,
    lat                     float8,
    lng                     float8
);
CREATE INDEX idx_emergencies_home_created ON emergencies (home_id, created_at);
