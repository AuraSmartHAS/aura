-- Triggers do AURA (Fase 7). Duas, uma de cada tipo que o enunciado cita:
--   TRG_REGRA_ALERTA_AUDITORIA    auditoria: toda mudança num limiar de aviso deixa o antes e o depois
--   TRG_MEDICACAO_ESTOQUE_BAIXO   automação: o estoque que cruza a linha vira aviso na mesma hora
--
-- A D-011 (Fase 6) descartou "lógica em triggers" porque uma falha da regra derrubaria a gravação da
-- leitura. A D-012 mantém esse cuidado: a trigger de automação não decide nada sozinha, chama o
-- package, e qualquer falha vira LOG_ERRO_PLSQL em vez de desfazer a dose confirmada. A de
-- auditoria, ao contrário, não engole erro: mudar um limiar sem deixar rastro não pode acontecer.

CREATE OR REPLACE TRIGGER trg_regra_alerta_auditoria
AFTER INSERT OR UPDATE OR DELETE ON regra_alerta
FOR EACH ROW
DECLARE
    -- INSERTING/UPDATING são predicados de PL/SQL: não valem dentro do VALUES de um INSERT.
    v_operacao regra_alerta_hist.operacao%TYPE :=
        CASE WHEN INSERTING THEN 'INSERT' WHEN UPDATING THEN 'UPDATE' ELSE 'DELETE' END;
BEGIN
    INSERT INTO regra_alerta_hist (
        codigo, operacao,
        severidade_antes, severidade_depois,
        limiar_antes, limiar_depois,
        janela_antes, janela_depois,
        ativa_antes, ativa_depois,
        versao_antes, versao_depois)
    VALUES (
        NVL(:NEW.codigo, :OLD.codigo),
        v_operacao,
        :OLD.severidade, :NEW.severidade,
        :OLD.limiar, :NEW.limiar,
        :OLD.janela_horas, :NEW.janela_horas,
        :OLD.ativa, :NEW.ativa,
        :OLD.versao, :NEW.versao);
END trg_regra_alerta_auditoria;
/

-- Dispara no cadastro e em toda mudança de estoque ou de horário: mais doses por dia também
-- encurtam a cobertura sem mexer no estoque. Lê só :OLD e :NEW; consultar MEDICATIONS aqui daria
-- ORA-04091 (tabela mutante), por isso a conta usa PKG_MEDICACAO.DIAS_COBERTURA, que não lê tabela.
CREATE OR REPLACE TRIGGER trg_medicacao_estoque_baixo
AFTER INSERT OR UPDATE OF stock_doses, schedule ON medications
FOR EACH ROW
WHEN (NEW.active = 1)
BEGIN
    pkg_alertas.avisar_estoque(
        p_home_id       => :NEW.home_id,
        p_medication_id => :NEW.id,
        p_nome          => :NEW.name,
        p_estoque_doses => :NEW.stock_doses,
        p_dias_antes    => pkg_medicacao.dias_cobertura(:OLD.stock_doses, :OLD.schedule),
        p_dias_depois   => pkg_medicacao.dias_cobertura(:NEW.stock_doses, :NEW.schedule));
EXCEPTION
    WHEN OTHERS THEN
        -- A dose confirmada vale mais que o aviso: a falha fica registrada e a gravação segue.
        pkg_apoio.log_erro('TRG_MEDICACAO_ESTOQUE_BAIXO', SQLCODE, SQLERRM);
END trg_medicacao_estoque_baixo;
/
