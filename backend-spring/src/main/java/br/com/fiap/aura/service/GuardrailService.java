package br.com.fiap.aura.service;

import br.com.fiap.aura.web.error.ApiException;
import java.text.Normalizer;
import java.util.List;
import java.util.Locale;
import org.springframework.stereotype.Service;

/**
 * RN-023 — o AURA nunca prescreve nem diagnostica. Todo texto que sai da API
 * (explicação do escore, motivo da recomendação) passa por aqui antes de ir ao cliente.
 */
@Service
public class GuardrailService {

    private static final List<String> BLOCKED = List.of(
            "prescrev", "prescric", "receit", "diagnostic", "tome ", "tomar ",
            "aumente a dose", "reduza a dose", "suspenda o remedio", "mg de ", "posologia");

    public String assertNonPrescriptive(String text) {
        if (text == null) {
            return null;
        }
        String normalized = Normalizer.normalize(text.toLowerCase(Locale.ROOT), Normalizer.Form.NFD)
                .replaceAll("\\p{M}", "");
        for (String term : BLOCKED) {
            if (normalized.contains(term)) {
                throw ApiException.unprocessable("PRESCRIPTION_BLOCKED",
                        "Conteúdo bloqueado: o AURA não prescreve nem diagnostica. Procure o médico.");
            }
        }
        return text;
    }
}
