package br.com.fiap.aura.web;

import br.com.fiap.aura.infra.OracleTestSupport;
import org.junit.jupiter.api.Tag;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;

/**
 * Os mesmos testes de {@link EmergencyFlowTest}, agora contra Oracle de verdade (tag oracle): prova de que
 * o backend é um só, com chaves estrangeiras reais, string vazia virando NULL e RAW(16) no lugar de
 * UUID. Herda tudo; só troca o banco.
 */
@Tag("oracle")
@ActiveProfiles(value = "oracle", inheritProfiles = false)
class EmergencyFlowOracleTest extends EmergencyFlowTest {

    @DynamicPropertySource
    static void oracle(DynamicPropertyRegistry registry) {
        OracleTestSupport.datasource(registry);
    }
}
