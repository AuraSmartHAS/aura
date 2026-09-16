package br.com.fiap.aura.infra;

import static org.assertj.core.api.Assertions.assertThat;

import br.com.fiap.aura.config.DataSeeder;
import br.com.fiap.aura.repository.HomeRepository;
import br.com.fiap.aura.repository.MedicationRepository;
import br.com.fiap.aura.repository.ProductRepository;
import br.com.fiap.aura.repository.SignalRepository;
import br.com.fiap.aura.repository.UserAccountRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Testcontainers;

/**
 * O único teste que roda contra PostgreSQL de verdade. A suíte rápida continua em H2; este existe
 * porque o banco do ensaio não pode ser o único lugar sem cobertura nenhuma.
 *
 * <p>O que ele prova, nesta ordem:
 *
 * <ol>
 *   <li><b>O baseline bate com as entidades.</b> O contexto sobe com {@code ddl-auto: validate} e o
 *       schema vindo só do Flyway. Qualquer divergência entre {@code V1__baseline.sql} e uma
 *       entidade derruba o contexto aqui — que é exatamente o acidente que o H2 escondia, porque
 *       ele recria tudo do zero a cada boot.
 *   <li><b>O seed popula.</b> Em banco vazio, os dados de demonstração entram.
 *   <li><b>Um segundo ciclo não duplica.</b> É o que sustenta o critério de aceite da task:
 *       reiniciar o backend preserva o que o ensaio criou. Rodar o seeder de novo sobre o MESMO
 *       banco é o equivalente em teste a subir a aplicação uma segunda vez.
 * </ol>
 *
 * <p>Precisa de Docker. Sem Docker o Testcontainers falha na largada, então o teste não entra na
 * suíte padrão; o runner o executa explicitamente (ver README).
 */
@Testcontainers
@SpringBootTest
@org.junit.jupiter.api.Tag("postgres")
class PostgresSchemaSmokeTest {

    @org.testcontainers.junit.jupiter.Container
    static final PostgreSQLContainer<?> POSTGRES =
            new PostgreSQLContainer<>("postgres:16-alpine")
                    .withDatabaseName("aura")
                    .withUsername("aura")
                    .withPassword("aura-teste");

    @DynamicPropertySource
    static void datasource(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        // O perfil dev (o padrao da suite) fixa o driver do H2; sem trocar aqui o contexto tenta
        // abrir uma URL postgres com o driver errado e nem chega no Flyway.
        registry.add("spring.datasource.driver-class-name", () -> "org.postgresql.Driver");
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
        // O ponto do teste: schema só do Flyway, Hibernate apenas conferindo.
        registry.add("spring.flyway.enabled", () -> "true");
        registry.add("spring.jpa.hibernate.ddl-auto", () -> "validate");
        registry.add("aura.seed.enabled", () -> "true");
    }

    @Autowired ProductRepository products;
    @Autowired UserAccountRepository users;
    @Autowired HomeRepository homes;
    @Autowired MedicationRepository medications;
    @Autowired SignalRepository signals;
    @Autowired DataSeeder seeder;

    @Test
    void baselineValidaContraAsEntidadesESeedPopula() {
        // Chegar aqui já significa que o contexto subiu com validate sobre o schema do Flyway.
        assertThat(products.count()).isPositive();
        assertThat(users.count()).isPositive();
        assertThat(homes.count()).isPositive();
        assertThat(medications.count()).isPositive();
        assertThat(signals.count()).isPositive();
    }

    @Test
    void segundoCicloDeSeedNaoDuplicaEPreservaOQueExiste() {
        long produtosAntes = products.count();
        long usuariosAntes = users.count();
        long casasAntes = homes.count();
        long sinaisAntes = signals.count();

        seeder.run();

        assertThat(products.count()).isEqualTo(produtosAntes);
        assertThat(users.count()).isEqualTo(usuariosAntes);
        assertThat(homes.count()).isEqualTo(casasAntes);
        assertThat(signals.count()).isEqualTo(sinaisAntes);
    }
}
