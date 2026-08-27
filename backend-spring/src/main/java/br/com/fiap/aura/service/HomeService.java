package br.com.fiap.aura.service;

import br.com.fiap.aura.domain.Home;
import br.com.fiap.aura.domain.HomeMember;
import br.com.fiap.aura.domain.enums.HomeMemberRole;
import br.com.fiap.aura.repository.HomeMemberRepository;
import br.com.fiap.aura.repository.HomeRepository;
import br.com.fiap.aura.security.AuthPrincipal;
import br.com.fiap.aura.web.dto.HomeDtos;
import br.com.fiap.aura.web.error.ApiException;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class HomeService {

    /** Coordenadas da região de referência da demo quando o CEP não traz geo. */
    private static final double DEMO_LAT = -23.561;
    private static final double DEMO_LNG = -46.656;

    private final HomeRepository homes;
    private final HomeMemberRepository members;
    private final GeoService geo;
    private final AuthService auth;

    public HomeService(HomeRepository homes, HomeMemberRepository members, GeoService geo, AuthService auth) {
        this.homes = homes;
        this.members = members;
        this.geo = geo;
        this.auth = auth;
    }

    @Transactional
    public HomeDtos.HomeCreatedResponse create(AuthPrincipal principal, HomeDtos.CreateHomeRequest req) {
        auth.requireConsent(principal);

        var address = geo.resolveCep(req.cep());
        Home home = homes.save(Home.builder()
                .ownerUserId(principal.userId())
                .patientName(req.patientName())
                .birthDate(req.birthDate())
                .label(req.label())
                .cep(req.cep())
                .address(address.map(GeoService.Address::formatted).orElse(null))
                .lat(DEMO_LAT)
                .lng(DEMO_LNG)
                .safetyChecklist(new LinkedHashMap<>())
                .build());

        // quem cria a casa entra como dona também no vínculo: assim toda casa tem membro desde o
        // primeiro segundo, e o C3 não precisa tratar "casa sem cuidador" como caso especial
        members.save(HomeMember.builder()
                .homeId(home.getId())
                .userId(principal.userId())
                .role(HomeMemberRole.DONO)
                .build());

        return new HomeDtos.HomeCreatedResponse(home.getId(), home.getAddress(), home.getLat(), home.getLng());
    }

    @Transactional(readOnly = true)
    public List<HomeDtos.HomeResponse> list(AuthPrincipal principal) {
        if (principal.isAdmin()) {
            return homes.findAll().stream().map(HomeService::toResponse).toList();
        }
        // a paciente não é dona da própria casa: sem o vínculo aqui, a lista dela voltaria vazia
        // e o app não teria de onde tirar o homeId da tela de voz
        List<UUID> vinculadas = members.findHomeIdsByUserId(principal.userId());
        return homes.findByIdInOrOwnerUserIdOrderByCreatedAtDesc(vinculadas, principal.userId())
                .stream().map(HomeService::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public HomeDtos.HomeResponse get(AuthPrincipal principal, UUID homeId) {
        return toResponse(requireAccess(principal, homeId));
    }

    @Transactional
    public HomeDtos.ChecklistResponse updateChecklist(AuthPrincipal principal, UUID homeId,
                                                      Map<String, Object> items) {
        Home home = requireAccess(principal, homeId);
        Map<String, Object> merged = new LinkedHashMap<>(home.getSafetyChecklist());
        merged.putAll(items);
        home.setSafetyChecklist(merged);
        return new HomeDtos.ChecklistResponse(merged);
    }

    /**
     * Isolamento por paciente (RN-017): casa de outro usuário responde 403, não 404 —
     * o cliente precisa distinguir "não é seu" de "não existe".
     *
     * <p>São três os caminhos de entrada, nesta ordem de custo: administrador (Torre de Controle),
     * dono da casa e vínculo em {@code home_members} (C0) — é por este último que a paciente entra
     * na própria casa. O vínculo só <b>soma</b> gente: quem não é nenhum dos três continua levando
     * 403, e é o que o teste de isolamento cobra.
     */
    @Transactional(readOnly = true)
    public Home requireAccess(AuthPrincipal principal, UUID homeId) {
        Home home = homes.findById(homeId).orElseThrow(() -> ApiException.notFound("Casa"));
        boolean liberado = principal.isAdmin()
                || home.getOwnerUserId().equals(principal.userId())
                || members.existsByHomeIdAndUserId(homeId, principal.userId());
        if (!liberado) {
            throw ApiException.forbidden();
        }
        return home;
    }

    static HomeDtos.HomeResponse toResponse(Home home) {
        return new HomeDtos.HomeResponse(home.getId(), home.getLabel(), home.getPatientName(),
                home.getBirthDate(), home.getCep(), home.getAddress(), home.getLat(), home.getLng(),
                home.getSafetyChecklist());
    }
}
