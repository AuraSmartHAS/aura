package br.com.fiap.aura.intelligence;

import java.time.LocalDate;
import java.time.ZoneId;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Profile;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Rotina automatizada: todo dia, logo depois da meia-noite de Brasília, fecha os indicadores do DIA
 * ANTERIOR de todas as casas (PRC_CONSOLIDAR_INDICADORES). Fechar "hoje" às 00h05 gravaria um dia de
 * cinco minutos, que ninguém revisaria depois. Só existe no perfil oracle.
 *
 * <p>Agendada no backend e não no DBMS_SCHEDULER: o usuário RM do servidor da FIAP pode não ter
 * permissão para criar job, e assim o agendamento fica versionado junto com o código.
 */
@Component
@Profile("oracle")
public class ConsolidacaoDiaria {

    private static final Logger log = LoggerFactory.getLogger(ConsolidacaoDiaria.class);
    private static final ZoneId BRASILIA = ZoneId.of("America/Sao_Paulo");

    private final CareIntelligence intelligence;

    public ConsolidacaoDiaria(CareIntelligence intelligence) {
        this.intelligence = intelligence;
    }

    @Scheduled(cron = "0 5 0 * * *", zone = "America/Sao_Paulo")
    @Transactional
    public void consolidar() {
        LocalDate ontem = LocalDate.now(BRASILIA).minusDays(1);
        int casas = intelligence.consolidarIndicadores(ontem);
        log.info("Indicadores de {} consolidados para {} casa(s)", ontem, casas);
    }
}
