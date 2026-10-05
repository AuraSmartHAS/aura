package br.com.fiap.aura.infra;

import java.time.Duration;
import org.junit.jupiter.api.Tag;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.oracle.OracleContainer;

/**
 * Base de todo teste que roda contra Oracle de verdade (tag {@code oracle}, fora da suíte padrão).
 *
 * <p>Um container só para a suíte inteira, iniciado uma vez e reaproveitado por todas as classes
 * filhas. Com {@code @Container} por classe, cada uma subiria o seu Oracle (2 GB de memória cada) e o
 * Spring não conseguiria reaproveitar o contexto entre elas. O Ryuk do Testcontainers derruba o
 * container quando a JVM termina.
 *
 * <p>Imagem fixada em vez de "23-slim-faststart": a tag flutuante muda de versão sem aviso.
 *
 * <p>Rodar: {@code ./mvnw test -Dtest.groups=oracle -Dtest.excludedGroups=}
 */
@SpringBootTest
@ActiveProfiles("oracle")
@Tag("oracle")
public abstract class OracleTestSupport {

    static final OracleContainer ORACLE =
            new OracleContainer("gvenzl/oracle-free:23.26.3-slim-faststart")
                    // usuário de aplicação, não SYSTEM: é o que o servidor da FIAP oferece (um RM)
                    .withUsername("aura")
                    .withPassword("aura-teste")
                    .withStartupTimeout(Duration.ofMinutes(3));

    static {
        ORACLE.start();
    }

    @DynamicPropertySource
    static void datasource(DynamicPropertyRegistry registry) {
        // O resto (validate, Flyway sem baseline, sem placeholder) vem do próprio perfil oracle:
        // o teste exercita a configuração que vai para a demo, não uma cópia dela.
        registry.add("spring.datasource.url", ORACLE::getJdbcUrl);
        registry.add("spring.datasource.username", ORACLE::getUsername);
        registry.add("spring.datasource.password", ORACLE::getPassword);
        registry.add("aura.seed.enabled", () -> "true");
    }
}
