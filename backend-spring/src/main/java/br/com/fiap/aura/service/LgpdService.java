package br.com.fiap.aura.service;

import br.com.fiap.aura.domain.Home;
import br.com.fiap.aura.repository.ConsentRepository;
import br.com.fiap.aura.repository.DeliveryOrderRepository;
import br.com.fiap.aura.repository.HomeRepository;
import br.com.fiap.aura.repository.MedicationRepository;
import br.com.fiap.aura.repository.RecommendationRepository;
import br.com.fiap.aura.repository.ScoreRepository;
import br.com.fiap.aura.repository.SignalRepository;
import br.com.fiap.aura.repository.UserAccountRepository;
import br.com.fiap.aura.security.AuthPrincipal;
import java.util.List;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Direito de exclusão (LGPD, art. 18): apagar de verdade, não marcar como inativo.
 * A ordem respeita as dependências — pedidos e recomendações antes da casa,
 * casas antes do usuário — porque o schema não usa cascata no banco.
 */
@Service
public class LgpdService {

    private static final Logger log = LoggerFactory.getLogger(LgpdService.class);

    private final HomeRepository homes;
    private final SignalRepository signals;
    private final ScoreRepository scores;
    private final RecommendationRepository recommendations;
    private final DeliveryOrderRepository orders;
    private final MedicationRepository medications;
    private final ConsentRepository consents;
    private final UserAccountRepository users;
    private final HomeService homeService;

    public LgpdService(HomeRepository homes, SignalRepository signals, ScoreRepository scores,
                       RecommendationRepository recommendations, DeliveryOrderRepository orders,
                       MedicationRepository medications, ConsentRepository consents,
                       UserAccountRepository users, HomeService homeService) {
        this.homes = homes;
        this.signals = signals;
        this.scores = scores;
        this.recommendations = recommendations;
        this.orders = orders;
        this.medications = medications;
        this.consents = consents;
        this.users = users;
        this.homeService = homeService;
    }

    /** Apaga a casa e tudo que foi observado nela. */
    @Transactional
    public void deleteHome(AuthPrincipal principal, UUID homeId) {
        Home home = homeService.requireAccess(principal, homeId);
        purgeHome(home.getId());
        homes.delete(home);
        log.info("Casa {} e dados associados excluídos a pedido do titular", homeId);
    }

    /** Apaga a conta, o consentimento e todas as casas do titular. */
    @Transactional
    public void deleteAccount(AuthPrincipal principal) {
        List<Home> owned = homes.findByOwnerUserIdOrderByCreatedAtDesc(principal.userId());
        owned.forEach(home -> purgeHome(home.getId()));
        homes.deleteAll(owned);
        consents.deleteByUserId(principal.userId());
        users.deleteById(principal.userId());
        log.info("Conta {} excluída a pedido do titular ({} casas)", principal.userId(), owned.size());
    }

    private void purgeHome(UUID homeId) {
        orders.deleteByHomeId(homeId);
        recommendations.deleteByHomeId(homeId);
        scores.deleteByHomeId(homeId);
        signals.deleteByHomeId(homeId);
        medications.deleteByHomeId(homeId);
    }
}
