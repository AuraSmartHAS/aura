package br.com.fiap.aura.service;

import br.com.fiap.aura.domain.StockNode;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

/**
 * Web service de geolocalização: endereço por CEP (ViaCEP) e distância até o nó
 * logístico mais próximo (ship-from-store). Falha de rede não derruba o cadastro —
 * a casa é criada sem endereço resolvido (degradação graciosa).
 */
@Service
public class GeoService {

    private static final Logger log = LoggerFactory.getLogger(GeoService.class);
    private static final double EARTH_RADIUS_M = 6_371_000;

    private final RestClient viaCep = RestClient.builder()
            .baseUrl("https://viacep.com.br/ws")
            .build();

    public record Address(String formatted, Double lat, Double lng) { }

    public Optional<Address> resolveCep(String cep) {
        if (cep == null || cep.isBlank()) {
            return Optional.empty();
        }
        String clean = cep.replaceAll("\\D", "");
        try {
            @SuppressWarnings("unchecked")
            Map<String, Object> body = viaCep.get().uri("/{cep}/json/", clean).retrieve().body(Map.class);
            if (body == null || Boolean.TRUE.equals(body.get("erro"))) {
                return Optional.empty();
            }
            String formatted = "%s, %s, %s, %s".formatted(
                    body.getOrDefault("logradouro", ""), body.getOrDefault("bairro", ""),
                    body.getOrDefault("localidade", ""), body.getOrDefault("uf", ""));
            return Optional.of(new Address(formatted.replaceAll("^,\\s*|,\\s*,", "").trim(), null, null));
        } catch (Exception e) {
            log.warn("ViaCEP indisponível para o CEP {} — casa segue sem endereço resolvido", clean);
            return Optional.empty();
        }
    }

    public double haversineMeters(double lat1, double lng1, double lat2, double lng2) {
        double dLat = Math.toRadians(lat2 - lat1);
        double dLng = Math.toRadians(lng2 - lng1);
        double a = Math.pow(Math.sin(dLat / 2), 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) * Math.pow(Math.sin(dLng / 2), 2);
        return EARTH_RADIUS_M * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }

    /** Nó mais próximo da casa; sem coordenadas, o primeiro cadastrado. */
    public Optional<StockNode> nearestNode(List<StockNode> nodes, Double lat, Double lng) {
        if (nodes.isEmpty()) {
            return Optional.empty();
        }
        if (lat == null || lng == null) {
            return Optional.of(nodes.get(0));
        }
        return nodes.stream().min((a, b) -> Double.compare(
                haversineMeters(lat, lng, a.getLat(), a.getLng()),
                haversineMeters(lat, lng, b.getLat(), b.getLng())));
    }
}
