package br.com.fiap.aura.infra;

import static org.assertj.core.api.Assertions.assertThat;

import br.com.fiap.aura.config.DataSeeder;
import br.com.fiap.aura.domain.Score;
import br.com.fiap.aura.repository.HomeRepository;
import br.com.fiap.aura.repository.ProductRepository;
import br.com.fiap.aura.repository.ScoreRepository;
import br.com.fiap.aura.repository.SignalRepository;
import br.com.fiap.aura.repository.UserAccountRepository;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * O mesmo backend sobre Oracle: o esquema de {@code db/migration/oracle} bate com as entidades, o
 * seed entra e nenhum objeto do banco ficou inválido.
 *
 * <p>Por que conferir {@code user_objects}: o Oracle aceita um {@code CREATE PROCEDURE} com erro de
 * compilação, grava o objeto como INVALID e o JDBC não lança nada. A migration fica verde e a
 * procedure só falha quando alguém a chama — na frente do professor.
 */
class OracleSchemaSmokeTest extends OracleTestSupport {

    @Autowired JdbcTemplate jdbc;
    @Autowired ProductRepository products;
    @Autowired UserAccountRepository users;
    @Autowired HomeRepository homes;
    @Autowired SignalRepository signals;
    @Autowired ScoreRepository scores;
    @Autowired DataSeeder seeder;

    @Test
    void esquemaValidaContraAsEntidadesESeedPopula() {
        // Chegar aqui já significa que o contexto subiu com validate sobre o schema do Flyway.
        assertThat(products.count()).isGreaterThan(100);
        assertThat(users.count()).isPositive();
        assertThat(homes.count()).isPositive();
        assertThat(signals.count()).isPositive();
    }

    @Test
    void nenhumObjetoDoEsquemaFicouInvalido() {
        List<String> invalidos = jdbc.queryForList(
                "SELECT object_type || ' ' || object_name FROM user_objects WHERE status = 'INVALID'",
                String.class);
        List<String> erros = jdbc.queryForList(
                "SELECT name || ' linha ' || line || ': ' || text FROM user_errors ORDER BY name, sequence",
                String.class);
        assertThat(invalidos).as("objetos inválidos; erros: %s", erros).isEmpty();
    }

    @Test
    void chavesEstrangeirasExistemNoBanco() {
        Integer fks = jdbc.queryForObject(
                "SELECT COUNT(*) FROM user_constraints WHERE constraint_type = 'R'", Integer.class);
        // 17 FKs no esquema base (V1); as tabelas de inteligência somam as delas.
        assertThat(fks).isGreaterThanOrEqualTo(17);
    }

    @Test
    void uuidSobreviveIdaEVoltaPeloRaw16() {
        Score qualquer = scores.findAll().get(0);
        String hex = jdbc.queryForObject(
                "SELECT RAWTOHEX(id) FROM scores WHERE id = HEXTORAW(?)",
                String.class, qualquer.getId().toString().replace("-", ""));
        assertThat(hex).isEqualToIgnoringCase(qualquer.getId().toString().replace("-", ""));
    }

    @Test
    void segundoCicloDeSeedNaoDuplica() {
        long antes = products.count();
        seeder.run();
        assertThat(products.count()).isEqualTo(antes);
    }
}
