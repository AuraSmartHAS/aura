-- =============================================================================================
-- Carga de dados simulados do AURA no Oracle (Fase 6)
--
-- Três casas com perfis opostos, para que os indicadores e os avisos tenham o que mostrar:
--   * Dona Lúcia  : toma quase tudo no horário, rotina estável      -> "tudo certo"
--   * Seu Jorge   : esquece doses, duas negadas nas últimas 48 h    -> avisos de adesão
--   * Dona Celina : a pulseira mostra os passos caindo nos últimos 3 dias -> aviso de rotina
--
-- Regras desta carga:
--   * Roda duas vezes sem duplicar: todo INSERT é MERGE por chave fixa (UUID fixo ou hash MD5
--     de um texto estável, que dá exatamente os 16 bytes de um RAW(16)).
--   * Datas relativas a hoje (fuso de São Paulo): no dia da correção os dados ainda são recentes.
--   * Não insere produto: os SKUs usados nas recomendações vêm do catálogo do app. Sem o
--     catálogo (instalação só por script), as recomendações são puladas, e o resto entra.
--   * Não usa nada exclusivo do 23ai/26ai (BOOLEAN em SQL, IF NOT EXISTS, VALUES com várias
--     linhas, SELECT sem FROM): roda igual num Oracle 19c, como o da FIAP.
--
-- Ordem (o carregar-dados.sh faz as três):
--   1. este script               -> casas, pessoas, medicações, doses, socorro, tabela de preparo
--   2. sqlldr leituras-pulseira  -> CSV da pulseira na tabela de preparo
--   3. importar-leituras.sql     -> preparo vira leitura (SIGNALS) e roda os avisos
-- =============================================================================================
SET DEFINE OFF
SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

PROMPT == Pessoas (familiares que cuidam) ==
-- Senha das contas simuladas: aura1234 (mesma das contas de demonstração do app).
MERGE INTO users u
USING (
  SELECT HEXTORAW('29F88512004A40BFA30B8BFA65D33062') id, 'renata@aura.com' email, 'Renata (filha)' name FROM dual UNION ALL
  SELECT HEXTORAW('872DD9AB2FB94180A3306495311766B8'), 'paulo@aura.com',  'Paulo (filho)'  FROM dual UNION ALL
  SELECT HEXTORAW('F9630EB97DDC4BB6BD2D653B899F64C2'), 'tiago@aura.com',  'Tiago (neto)'   FROM dual
) s ON (u.email = s.email)
WHEN NOT MATCHED THEN INSERT (id, email, password_hash, role, name, created_at)
VALUES (s.id, s.email, '$2a$10$ItY20oKwxUJXWZ1kQ8bvNuIGfuLvoGMycCw7ya2P8MlIWTjH/hHrm',
        'CUIDADORA', s.name, SYSTIMESTAMP - INTERVAL '30' DAY);

MERGE INTO consents c
USING (
  SELECT HEXTORAW('F11E3A33BC104E739073962FF1271E56') id, HEXTORAW('29F88512004A40BFA30B8BFA65D33062') user_id FROM dual UNION ALL
  SELECT HEXTORAW('E03D395B190F499282E376676D8E0682'), HEXTORAW('872DD9AB2FB94180A3306495311766B8') FROM dual UNION ALL
  SELECT HEXTORAW('A92F10B9BB3B430EB8AEDF1AB0470F05'), HEXTORAW('F9630EB97DDC4BB6BD2D653B899F64C2') FROM dual
) s ON (c.id = s.id)
WHEN NOT MATCHED THEN INSERT (id, user_id, version, accepted_at)
VALUES (s.id, s.user_id, '2026-06', SYSTIMESTAMP - INTERVAL '30' DAY);

PROMPT == Casas ==
MERGE INTO homes h
USING (
  SELECT HEXTORAW('F772466B06604608AA9CBFC1C79440FA') id, HEXTORAW('29F88512004A40BFA30B8BFA65D33062') owner,
         'Lúcia Ferreira' patient, DATE '1944-03-12' birth, 'Casa da Dona Lúcia' label, '04101-000' cep,
         'Vila Mariana, São Paulo - SP' address, -23.5893 lat, -46.6347 lng,
         '{"grab_bar_bathroom":true,"anti_slip_floor":true,"night_light":true,"gas_detector":true,"air_purifier":false}' chk
    FROM dual UNION ALL
  SELECT HEXTORAW('1B5ED8CB31E14D2DA4E4C227DAF19BD1'), HEXTORAW('872DD9AB2FB94180A3306495311766B8'),
         'Jorge Almeida', DATE '1941-08-02', 'Casa do Seu Jorge', '03310-000',
         'Tatuapé, São Paulo - SP', -23.5403, -46.5763,
         '{"grab_bar_bathroom":false,"anti_slip_floor":true,"night_light":false,"gas_detector":false,"air_purifier":false}'
    FROM dual UNION ALL
  SELECT HEXTORAW('2B6288E7F958490BBF80B86083E7A882'), HEXTORAW('F9630EB97DDC4BB6BD2D653B899F64C2'),
         'Celina Souza', DATE '1946-11-25', 'Casa da Dona Celina', '05415-000',
         'Pinheiros, São Paulo - SP', -23.5667, -46.6912,
         '{"grab_bar_bathroom":true,"anti_slip_floor":false,"night_light":true,"gas_detector":true,"air_purifier":true}'
    FROM dual
) s ON (h.id = s.id)
WHEN NOT MATCHED THEN INSERT (id, owner_user_id, patient_name, birth_date, label, cep, address, lat, lng,
                              safety_checklist, created_at)
VALUES (s.id, s.owner, s.patient, s.birth, s.label, s.cep, s.address, s.lat, s.lng, s.chk,
        SYSTIMESTAMP - INTERVAL '30' DAY);

MERGE INTO home_members m
USING (
  SELECT HEXTORAW('AC22F801ED874C8BB54340D65D7CC4DB') id, HEXTORAW('F772466B06604608AA9CBFC1C79440FA') home_id,
         HEXTORAW('29F88512004A40BFA30B8BFA65D33062') user_id FROM dual UNION ALL
  SELECT HEXTORAW('F58A8146991042E5B55A3701523D4DC9'), HEXTORAW('1B5ED8CB31E14D2DA4E4C227DAF19BD1'),
         HEXTORAW('872DD9AB2FB94180A3306495311766B8') FROM dual UNION ALL
  SELECT HEXTORAW('F2F8F06EC64F4A05ACD580A34492BDB9'), HEXTORAW('2B6288E7F958490BBF80B86083E7A882'),
         HEXTORAW('F9630EB97DDC4BB6BD2D653B899F64C2') FROM dual
) s ON (m.home_id = s.home_id AND m.user_id = s.user_id)
WHEN NOT MATCHED THEN INSERT (id, home_id, user_id, role, created_at)
VALUES (s.id, s.home_id, s.user_id, 'DONO', SYSTIMESTAMP - INTERVAL '30' DAY);

PROMPT == Medicações ==
-- Sem instrução de uso nas notas: o AURA nunca ecoa orientação de dose.
MERGE INTO medications m
USING (
  SELECT HEXTORAW('D2D7F889F3F54B4881FE9CEFA5BB53C0') id, HEXTORAW('F772466B06604608AA9CBFC1C79440FA') home_id,
         'Levotiroxina' name, '1 comprimido' dosage, '["06:00"]' schedule, 40 stock FROM dual UNION ALL
  SELECT HEXTORAW('88A3CBF9509443E69D5D0F39BDB9FE1F'), HEXTORAW('F772466B06604608AA9CBFC1C79440FA'),
         'Sinvastatina', '1 comprimido', '["20:00"]', 35 FROM dual UNION ALL
  SELECT HEXTORAW('624F8907D8FB46F0B633BDB94A7CA249'), HEXTORAW('1B5ED8CB31E14D2DA4E4C227DAF19BD1'),
         'Metformina', '1 comprimido', '["08:00","20:00"]', 6 FROM dual UNION ALL
  SELECT HEXTORAW('13313517F4EC430F812A5287E7FF0A46'), HEXTORAW('1B5ED8CB31E14D2DA4E4C227DAF19BD1'),
         'Losartana', '1 comprimido', '["08:00"]', 18 FROM dual UNION ALL
  SELECT HEXTORAW('60E1F5E1E48D442095BA92B8112A8D8F'), HEXTORAW('2B6288E7F958490BBF80B86083E7A882'),
         'Donepezila', '1 comprimido', '["20:00"]', 25 FROM dual
) s ON (m.id = s.id)
WHEN NOT MATCHED THEN INSERT (id, home_id, name, dosage, schedule, notes, stock_doses, active, created_at)
VALUES (s.id, s.home_id, s.name, s.dosage, s.schedule, NULL, s.stock, 1, SYSTIMESTAMP - INTERVAL '30' DAY);

PROMPT == Histórico de doses (21 dias) ==
-- Uma leitura ADHERENCE por horário passado, no mesmo formato que o app grava ao confirmar
-- uma dose: {"medicationId":"<uuid>","taken":true|false}. Quem esquece, e quando, é
-- determinístico (MOD), para a carga dar sempre o mesmo resultado.
DECLARE
  -- Hoje no fuso de São Paulo, à meia-noite. O container roda em UTC.
  v_hoje      DATE := TRUNC(CAST(SYSTIMESTAMP AT TIME ZONE 'America/Sao_Paulo' AS DATE));
  v_quando    TIMESTAMP WITH TIME ZONE;
  v_tomou     BOOLEAN;
  -- O texto do JSON sai em PL/SQL: BOOLEAN dentro de SQL só existe no 23ai e quebraria num 19c.
  v_taken     VARCHAR2(5);
  v_inseridas PLS_INTEGER := 0;

  -- Medicações desta carga com o perfil de esquecimento de cada casa.
  CURSOR c_meds IS
    SELECT m.id, m.home_id, m.schedule,
           fn_uuid_texto(m.id) AS id_texto,  -- o mesmo texto que o Java grava no JSON
           CASE m.home_id
             WHEN HEXTORAW('1B5ED8CB31E14D2DA4E4C227DAF19BD1') THEN 'esquece'
             ELSE 'regular'
           END AS perfil
      FROM medications m
     WHERE m.home_id IN (HEXTORAW('F772466B06604608AA9CBFC1C79440FA'),
                         HEXTORAW('1B5ED8CB31E14D2DA4E4C227DAF19BD1'),
                         HEXTORAW('2B6288E7F958490BBF80B86083E7A882'));
BEGIN
  FOR med IN c_meds LOOP
    FOR horario IN (SELECT hh FROM JSON_TABLE(med.schedule, '$[*]' COLUMNS (hh VARCHAR2(5) PATH '$'))) LOOP
      FOR d IN 0 .. 20 LOOP
        v_quando := FROM_TZ(CAST(v_hoje - d AS TIMESTAMP)
                            + NUMTODSINTERVAL(TO_NUMBER(SUBSTR(horario.hh, 1, 2)), 'HOUR')
                            + NUMTODSINTERVAL(TO_NUMBER(SUBSTR(horario.hh, 4, 2)), 'MINUTE'),
                            'America/Sao_Paulo');
        IF v_quando <= SYSTIMESTAMP THEN
          IF med.perfil = 'esquece' THEN
            -- Seu Jorge: esquece ~4 em cada 10 e não tomou nada nos últimos 2 dias.
            v_tomou := d >= 2 AND MOD(d * 7 + TO_NUMBER(SUBSTR(horario.hh, 1, 2)), 10) >= 4;
          ELSE
            -- Lúcia e Celina: esquecem uma vez a cada duas semanas, mais ou menos.
            v_tomou := MOD(d * 3 + TO_NUMBER(SUBSTR(horario.hh, 1, 2)), 14) <> 5;
          END IF;

          v_taken := CASE WHEN v_tomou THEN 'true' ELSE 'false' END;

          MERGE INTO signals s
          USING (SELECT STANDARD_HASH('dose|' || med.id_texto || '|' || TO_CHAR(v_quando, 'YYYYMMDDHH24MI'), 'MD5') id
                   FROM dual) k
          ON (s.id = k.id)
          WHEN NOT MATCHED THEN INSERT (id, home_id, type, source, signal_value, captured_at)
          VALUES (k.id, med.home_id, 'ADHERENCE', 'SELF_REPORT',
                  '{"medicationId":"' || med.id_texto || '","taken":' || v_taken || '}',
                  v_quando);
          v_inseridas := v_inseridas + SQL%ROWCOUNT;
        END IF;
      END LOOP;
    END LOOP;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('Doses registradas nesta execução: ' || v_inseridas);
END;
/

PROMPT == Relatos (quase-queda e tontura) ==
MERGE INTO signals s
USING (
  SELECT STANDARD_HASH('relato|jorge|tontura', 'MD5') id, HEXTORAW('1B5ED8CB31E14D2DA4E4C227DAF19BD1') home_id,
         'MOBILITY' type, 'VOICE' source, '{"event":"dizziness","place":"bathroom"}' val, 4 dias FROM dual UNION ALL
  SELECT STANDARD_HASH('relato|celina|viagem-noturna', 'MD5'), HEXTORAW('2B6288E7F958490BBF80B86083E7A882'),
         'SLEEP', 'VOICE', '{"event":"night_trip","times":3}', 2 FROM dual
) r ON (s.id = r.id)
WHEN NOT MATCHED THEN INSERT (id, home_id, type, source, signal_value, captured_at)
VALUES (r.id, r.home_id, r.type, r.source, r.val, SYSTIMESTAMP - NUMTODSINTERVAL(r.dias, 'DAY'));

PROMPT == Histórico de socorro (SOS) ==
-- Dois pedidos antigos do Seu Jorge, já confirmados por quem foi ajudar. Servem de histórico
-- para o tempo de resposta; nenhum dispara aviso novo.
MERGE INTO emergencies e
USING (
  SELECT HEXTORAW('8CF2DCE3BE104B7FBA1058ACBD101A6B') id, 12 dias, 95 resposta_s FROM dual UNION ALL
  SELECT HEXTORAW('DDAF27503ACC45EDBD264125B30F5F4C'), 5, 140 FROM dual
) s ON (e.id = s.id)
WHEN NOT MATCHED THEN INSERT (id, home_id, triggered_by_user_id, channel, state, created_at, dispatch_due_at,
                              dispatched_at, acknowledged_at, acknowledged_by_user_id, state_changed_at,
                              transport_real, notified_count, escalated_count, retraction_sent, lat, lng)
VALUES (s.id, HEXTORAW('1B5ED8CB31E14D2DA4E4C227DAF19BD1'), NULL, 'TOUCH', 'ACKNOWLEDGED',
        SYSTIMESTAMP - NUMTODSINTERVAL(s.dias, 'DAY'),
        SYSTIMESTAMP - NUMTODSINTERVAL(s.dias, 'DAY') + INTERVAL '5' SECOND,
        SYSTIMESTAMP - NUMTODSINTERVAL(s.dias, 'DAY') + INTERVAL '5' SECOND,
        SYSTIMESTAMP - NUMTODSINTERVAL(s.dias, 'DAY') + NUMTODSINTERVAL(5 + s.resposta_s, 'SECOND'),
        HEXTORAW('872DD9AB2FB94180A3306495311766B8'),
        SYSTIMESTAMP - NUMTODSINTERVAL(s.dias, 'DAY') + NUMTODSINTERVAL(5 + s.resposta_s, 'SECOND'),
        0, 1, 0, 0, -23.5403, -46.5763);

PROMPT == Recomendações aprovadas (só se o catálogo do app estiver carregado) ==
-- O INSERT ... SELECT FROM products devolve zero linhas quando o SKU não existe: sem catálogo,
-- a carga segue sem recomendação em vez de quebrar na chave estrangeira.
INSERT INTO recommendations (id, home_id, score_id, medication_id, sku, reason, status, factors, weights, created_at)
SELECT HEXTORAW('5E904DC6727140D693A27B02C560A6C3'), HEXTORAW('1B5ED8CB31E14D2DA4E4C227DAF19BD1'), NULL, NULL,
       p.sku, 'Recomendamos iluminação noturna porque houve tontura e a casa não tem luz noturna.',
       'approved', '["poor_night_lighting"]', '[0.4]', SYSTIMESTAMP - INTERVAL '3' DAY
  FROM products p
 WHERE p.sku = 'LM-LUZ-SENSOR'
   AND NOT EXISTS (SELECT 1 FROM recommendations r WHERE r.id = HEXTORAW('5E904DC6727140D693A27B02C560A6C3'));

INSERT INTO recommendations (id, home_id, score_id, medication_id, sku, reason, status, factors, weights, created_at)
SELECT HEXTORAW('E104CB4577BE4B5E8C5444C4261F0614'), HEXTORAW('1B5ED8CB31E14D2DA4E4C227DAF19BD1'), NULL, NULL,
       p.sku, 'Recomendamos o kit de barras porque houve tontura no banheiro e a casa não tem barra de apoio.',
       'approved', '["no_grab_bar","dizziness_bath"]', '[0.3,0.1]', SYSTIMESTAMP - INTERVAL '2' DAY
  FROM products p
 WHERE p.sku = 'LM-1566953614'
   AND NOT EXISTS (SELECT 1 FROM recommendations r WHERE r.id = HEXTORAW('E104CB4577BE4B5E8C5444C4261F0614'));

PROMPT == Tabela de preparo da pulseira (recebe o CSV pelo SQL*Loader) ==
-- Fica fora do modelo do app (não entra no DER): é só a porta de entrada do arquivo.
DECLARE
  e_ja_existe EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_ja_existe, -955);
BEGIN
  EXECUTE IMMEDIATE q'[
    CREATE TABLE stg_leitura_pulseira (
      casa_id    VARCHAR2(32) NOT NULL,
      dias_atras NUMBER(3)    NOT NULL,
      passos     NUMBER(6),
      fc_repouso NUMBER(3),
      sono_horas NUMBER(3,1)
    )]';
  DBMS_OUTPUT.PUT_LINE('Tabela STG_LEITURA_PULSEIRA criada.');
EXCEPTION
  WHEN e_ja_existe THEN
    DBMS_OUTPUT.PUT_LINE('Tabela STG_LEITURA_PULSEIRA já existia; segue.');
END;
/

COMMIT;
PROMPT == Carga simulada concluída ==
