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
