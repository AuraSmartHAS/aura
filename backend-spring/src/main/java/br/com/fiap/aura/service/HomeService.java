package br.com.fiap.aura.service;

import br.com.fiap.aura.domain.Home;
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
    private final GeoService geo;
    private final AuthService auth;

    public HomeService(HomeRepository homes, GeoService geo, AuthService auth) {
        this.homes = homes;
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

        return new HomeDtos.HomeCreatedResponse(home.getId(), home.getAddress(), home.getLat(), home.getLng());
    }

    @Transactional(readOnly = true)
    public List<HomeDtos.HomeResponse> list(AuthPrincipal principal) {
        List<Home> found = principal.isAdmin()
                ? homes.findAll()
                : homes.findByOwnerUserIdOrderByCreatedAtDesc(principal.userId());
        return found.stream().map(HomeService::toResponse).toList();
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
     */
    @Transactional(readOnly = true)
    public Home requireAccess(AuthPrincipal principal, UUID homeId) {
        Home home = homes.findById(homeId).orElseThrow(() -> ApiException.notFound("Casa"));
        if (!principal.isAdmin() && !home.getOwnerUserId().equals(principal.userId())) {
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
