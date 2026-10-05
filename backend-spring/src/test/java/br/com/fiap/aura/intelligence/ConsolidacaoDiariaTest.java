package br.com.fiap.aura.intelligence;

import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

import java.time.LocalDate;
import java.time.ZoneId;
import org.junit.jupiter.api.Test;

/** O job das 00h05 fecha o dia que terminou, não o que acabou de começar. */
class ConsolidacaoDiariaTest {

    @Test
    void consolidaOntemNoFusoDeBrasilia() {
        CareIntelligence intelligence = mock(CareIntelligence.class);

        new ConsolidacaoDiaria(intelligence).consolidar();

        verify(intelligence).consolidarIndicadores(
                LocalDate.now(ZoneId.of("America/Sao_Paulo")).minusDays(1));
    }
}
