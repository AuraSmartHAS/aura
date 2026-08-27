package br.com.fiap.aura.service;

import br.com.fiap.aura.domain.StockNode;
import java.util.ArrayList;
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

    /** Velocidade média urbana usada para estimar a duração da entrega (25 km/h em m/s). */
    private static final double AVG_URBAN_SPEED_MS = 25_000 / 3_600d;
    private static final int ROUTE_POINTS = 7;
    private static final double ROUTE_BULGE = 0.09;
    private static final double ROUTE_WIGGLE = 0.02;

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

    /** Polilinha do nó até a casa (pares [lng, lat], ordem do GeoJSON) e duração estimada em segundos. */
    public record SimulatedRoute(List<List<Double>> coordinates, int durationS) { }

    /**
     * Rota e duração da entrega são SIMULADAS para a demonstração — não há integração com
     * serviço de roteamento nem malha viária aqui. Premissas, explícitas de propósito:
     * a polilinha é a reta nó→casa deslocada por um arco suave com leve serpenteado (só para
     * o mapa não desenhar um traço artificial), e a duração é a distância em linha reta
     * dividida por 25 km/h, média de trânsito urbano. É determinística: a mesma casa e o
     * mesmo nó devolvem sempre a mesma rota. Sem coordenadas, devolve vazio — e o cliente
     * degrada para o estado vazio do mapa.
     */
    public Optional<SimulatedRoute> simulateRoute(Double fromLat, Double fromLng, Double toLat, Double toLng) {
        if (fromLat == null || fromLng == null || toLat == null || toLng == null) {
            return Optional.empty();
        }
        double deltaLat = toLat - fromLat;
        double deltaLng = toLng - fromLng;
        double span = Math.hypot(deltaLat, deltaLng);
        // perpendicular unitária ao trecho: é nela que os vértices do meio são deslocados
        double perpLat = span == 0 ? 0 : -deltaLng / span;
        double perpLng = span == 0 ? 0 : deltaLat / span;

        List<List<Double>> coordinates = new ArrayList<>(ROUTE_POINTS);
        for (int i = 0; i < ROUTE_POINTS; i++) {
            double t = (double) i / (ROUTE_POINTS - 1);
            // os dois senos zeram nas pontas: a rota começa no nó e termina na casa, exatamente
            double offset = span * (ROUTE_BULGE * Math.sin(Math.PI * t) + ROUTE_WIGGLE * Math.sin(3 * Math.PI * t));
            coordinates.add(List.of(round6(fromLng + deltaLng * t + perpLng * offset),
                    round6(fromLat + deltaLat * t + perpLat * offset)));
        }

        long durationS = Math.round(haversineMeters(fromLat, fromLng, toLat, toLng) / AVG_URBAN_SPEED_MS);
        return Optional.of(new SimulatedRoute(coordinates, (int) Math.max(durationS, 1)));
    }

    private double round6(double value) {
        return Math.round(value * 1_000_000d) / 1_000_000d;
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
