-- `level` vira `risk_level` em todos os bancos (Fase 6).
--
-- No Oracle, LEVEL é palavra reservada (CONNECT BY): a coluna só existiria entre aspas, e aí todo
-- SQL e todo PL/SQL que tocasse nela teria de repetir as aspas. Renomear aqui mantém o mesmo nome
-- físico nos dois bancos, então a entidade continua com um @Column só.
--
-- RENAME preserva os dados. Atenção: não tem volta automática — um banco migrado por esta versão
-- não valida mais com o código de antes dela (o Hibernate procuraria `level`).

ALTER TABLE scores RENAME COLUMN level TO risk_level;
