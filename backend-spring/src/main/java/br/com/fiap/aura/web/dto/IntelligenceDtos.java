package br.com.fiap.aura.web.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * Contrato das rotas da camada de inteligência no banco (Fase 6).
 *
 * <p>Toda resposta traz {@code engine}: {@code "oracle"} quando o PL/SQL respondeu, ou
 * {@code "indisponivel"} quando o backend roda em H2/PostgreSQL. Indisponível não é erro: as
 * listas vêm vazias, os números nulos e o status é 200, para o painel esconder o card em vez de
 * mostrar falha.
 */
public final class IntelligenceDtos {

    private IntelligenceDtos() { }

    @Schema(description = "Aviso gravado pelo banco (PRC_REGISTRAR_ALERTAS). `regra` é o código de REGRA_ALERTA.")
    public record Alerta(UUID id,
                         @Schema(example = "QUASE_QUEDA") String regra,
                         @Schema(example = "alta", allowableValues = {"info", "atencao", "alta"}) String severidade,
                         @Schema(example = "Quase-queda registrada · banheiro · por voz · 04/10 14:32") String mensagem,
                         @Schema(example = "aberto", allowableValues = {"aberto", "visto"}) String status,
                         Instant criadoEm) { }

    public record AlertasResponse(@Schema(example = "oracle") String engine, List<Alerta> alertas) { }

    public record ProcessarResponse(@Schema(example = "oracle") String engine, int novos) { }

    public record VistoResponse(UUID id, @Schema(example = "visto") String status) { }

    @Schema(description = "Uma medicação ativa no período. `adesaoPct` vem de FN_TAXA_ADESAO; nulo = sem dado.")
    public record ItemConsumo(String medicamento, int dosesConfirmadas, int dosesNegadas, int dosesEsperadas,
                              BigDecimal adesaoPct, Integer estoqueDoses) { }

    @Schema(description = """
            Relatório resumido de consumo (PRC_RELATORIO_CONSUMO). `demandaEncaminhadaReais` é a soma do
            preço de referência dos itens aprovados no período: demanda encaminhada a parceiros, não compra.""")
    public record RelatorioConsumoResponse(@Schema(example = "oracle") String engine, LocalDate de, LocalDate ate,
                                           Integer totalDoses, BigDecimal demandaEncaminhadaReais,
                                           List<ItemConsumo> itens) { }

    public record IndicadorCasa(UUID homeId, String casa, BigDecimal adesaoPct, BigDecimal variacaoPassosPct,
                                int alertasAbertos, Instant atualizadoEm) { }

    @Schema(description = "Indicadores do dia mais recente consolidado (INDICADOR_DIARIO).")
    public record IndicadoresResponse(@Schema(example = "oracle") String engine, LocalDate dataRef,
                                      List<IndicadorCasa> casas) { }

    public record ConsolidarResponse(@Schema(example = "oracle") String engine, int casasProcessadas) { }
}
