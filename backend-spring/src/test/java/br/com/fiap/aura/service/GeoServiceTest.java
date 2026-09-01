package br.com.fiap.aura.service;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/** Interpolação ao longo da polilinha simulada — função pura, sem Spring. */
class GeoServiceTest {

    private final GeoService geo = new GeoService();

    /** A mesma geometria do seed: Loja Marginal → casa da Maria, ~2 km. */
    private List<List<Double>> route() {
        return geo.simulateRoute(-23.55, -46.64, -23.561, -46.656).orElseThrow().coordinates();
    }

    @Test
    @DisplayName("fração 0 é o nó de origem e fração 1 é a casa")
    void extremes() {
        List<List<Double>> coords = route();
        assertThat(geo.positionAlong(coords, 0)).isEqualTo(coords.get(0));
        assertThat(geo.positionAlong(coords, 1)).isEqualTo(coords.get(coords.size() - 1));
    }

    @Test
    @DisplayName("fração fora de [0, 1] é grampeada nas pontas, nunca extrapola a rota")
    void clamped() {
        List<List<Double>> coords = route();
        assertThat(geo.positionAlong(coords, -0.5)).isEqualTo(coords.get(0));
        assertThat(geo.positionAlong(coords, 1.5)).isEqualTo(coords.get(coords.size() - 1));
    }

    @Test
    @DisplayName("a posição avança de forma monotônica com a fração")
    void monotonic() {
        List<List<Double>> coords = route();
        // nesta geometria a rota anda para oeste: longitude estritamente decrescente
        double previousLng = geo.positionAlong(coords, 0).get(0);
        for (int i = 1; i <= 9; i++) {
            double lng = geo.positionAlong(coords, i / 10d).get(0);
            assertThat(lng).isLessThan(previousLng);
            previousLng = lng;
        }
    }

    @Test
    @DisplayName("polilinha degenerada não explode")
    void degenerate() {
        assertThat(geo.positionAlong(null, 0.5)).isEmpty();
        assertThat(geo.positionAlong(List.of(), 0.5)).isEmpty();

        List<Double> only = List.of(-46.64, -23.55);
        assertThat(geo.positionAlong(List.of(only), 0.5)).isEqualTo(only);
        // dois pontos iguais: comprimento zero, devolve a origem em vez de dividir por zero
        assertThat(geo.positionAlong(List.of(only, only), 0.7)).isEqualTo(only);
    }
}
