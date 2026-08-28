package br.com.fiap.aura.config;

import br.com.fiap.aura.domain.enums.SignalType;
import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Configuração do AURA. Os fatores e pesos do escore vivem em
 * {@code scoring-weights.yml} — versionados e auditáveis, nunca "mágicos" no código.
 */
@ConfigurationProperties(prefix = "aura")
public record AuraProperties(Jwt jwt, Scoring scoring, Carechain carechain, Cors cors, Seed seed, Push push) {

    public record Jwt(String secret, long accessTtlMinutes, long refreshTtlDays) { }

    public record Scoring(int windowDays, String configVersion, Levels levels, Map<String, Dimension> dimensions) { }

    public record Levels(double medium, double high) { }

    public record Dimension(String norm, String riskTag, List<Factor> factors) { }

    public enum FactorKind {
        /** 1 se houver ao menos um sinal {tipo, evento} na janela. */
        SIGNAL_EVENT,
        /** 1 se a chave do checklist for verdadeira (o risco está presente). */
        CHECKLIST_PRESENT,
        /** 1 se a chave do checklist for falsa/ausente (falta o item de segurança). */
        CHECKLIST_ABSENT
    }

    public record Factor(String name, String label, double weight, FactorKind kind,
                         SignalType signalType, String event, String checklistKey) { }

    /**
     * Política comercial da Care-Chain. A instalação vive aqui, e não no {@code Product},
     * porque o catálogo ainda não tem preço de instalação por SKU — e a cuidadora precisa
     * saber quanto vai pagar antes de aprovar, não depois.
     */
    public record Carechain(int deliverySlaHours, int installSlaHours,
                            boolean installationIncluded, BigDecimal installationPrice) { }

    public record Cors(String allowedOrigins) { }

    public record Seed(boolean enabled) { }

    /**
     * Credencial do Firebase para o push (C2). Nunca versionada: vem de variável de ambiente,
     * como caminho da conta de serviço ({@code credentialsPath}) ou como o JSON inteiro
     * ({@code credentialsJson}) — o segundo existe para plataformas que só oferecem variável.
     *
     * <p>Vazio nos dois é o estado normal do CI e do desenvolvimento: sem credencial o transporte
     * real não é registrado e o envio se declara {@code simulated}. Ver {@link FirebaseConfig}.
     */
    public record Push(String credentialsPath, String credentialsJson) { }
}
