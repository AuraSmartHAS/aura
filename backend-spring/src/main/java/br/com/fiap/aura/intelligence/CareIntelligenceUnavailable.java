package br.com.fiap.aura.intelligence;

import br.com.fiap.aura.web.dto.IntelligenceDtos;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

/**
 * H2 (suíte de testes e demo rápida) e PostgreSQL não têm o PL/SQL. Em vez de erro 500, a camada
 * responde "indisponível": listas vazias, números nulos. O painel esconde os cards quando vê isso.
 */
@Component
@Profile("!oracle")
public class CareIntelligenceUnavailable implements CareIntelligence {

    @Override
    public String engine() {
        return INDISPONIVEL;
    }

    @Override
    public int registrarAlertas(UUID homeId) {
        return 0;
    }

    @Override
    public List<IntelligenceDtos.Alerta> listarAlertas(UUID homeId, int limite) {
        return List.of();
    }

    @Override
    public Optional<UUID> casaDoAlerta(UUID alertaId) {
        return Optional.empty();
    }

    @Override
    public void marcarVisto(UUID alertaId) {
        // sem banco de avisos, não há o que marcar; a rota responde 404 antes de chegar aqui
    }

    @Override
    public IntelligenceDtos.RelatorioConsumoResponse relatorioConsumo(UUID homeId, LocalDate de, LocalDate ate) {
        return new IntelligenceDtos.RelatorioConsumoResponse(INDISPONIVEL, de, ate, null, null, List.of());
    }

    @Override
    public int consolidarIndicadores(LocalDate dataRef) {
        return 0;
    }

    @Override
    public IntelligenceDtos.IndicadoresResponse indicadores() {
        return new IntelligenceDtos.IndicadoresResponse(INDISPONIVEL, null, List.of());
    }
}
