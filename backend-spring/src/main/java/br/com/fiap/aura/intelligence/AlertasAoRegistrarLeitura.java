package br.com.fiap.aura.intelligence;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * O evento de backend que aciona o PL/SQL: REST → Java → JDBC → Oracle.
 *
 * <p><b>AFTER_COMMIT</b>: a procedure só enxerga a leitura depois que ela foi gravada de verdade.
 * Antes do commit, o PL/SQL rodaria noutra sessão e não veria a linha nova.
 *
 * <p><b>REQUIRES_NEW</b>: depois do commit a conexão da requisição ainda está presa à thread, só que
 * numa transação que ninguém mais vai commitar. Sem transação nova, o INSERT dos avisos entraria
 * nela e sumiria em silêncio no rollback que o pool faz ao devolver a conexão — o teste passaria e
 * o banco não teria nada.
 *
 * <p>Falha aqui vira log, nunca erro para quem registrou a leitura: a leitura já está salva, e o
 * aviso pode ser refeito a qualquer momento por {@code POST /homes/{id}/alertas/processar}.
 *
 * <p>O SOS não publica este evento de propósito: ele responde antes de qualquer chamada de rede e já
 * tem o próprio push. Pôr o Oracle no caminho do socorro só acrescentaria espera.
 */
@Component
public class AlertasAoRegistrarLeitura {

    private static final Logger log = LoggerFactory.getLogger(AlertasAoRegistrarLeitura.class);

    private final CareIntelligence intelligence;

    public AlertasAoRegistrarLeitura(CareIntelligence intelligence) {
        this.intelligence = intelligence;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void aoRegistrarLeitura(LeituraRegistrada evento) {
        if (!CareIntelligence.ORACLE.equals(intelligence.engine())) {
            return;
        }
        try {
            int novos = intelligence.registrarAlertas(evento.homeId());
            if (novos > 0) {
                log.info("{} aviso(s) novo(s) gravado(s) pelo banco para a casa {}", novos, evento.homeId());
            }
        } catch (RuntimeException e) {
            log.warn("Avisos da casa {} não foram processados agora: {}", evento.homeId(), e.getMessage());
        }
    }
}
