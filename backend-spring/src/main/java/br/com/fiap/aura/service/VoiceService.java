package br.com.fiap.aura.service;

import br.com.fiap.aura.web.error.ApiException;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

/**
 * Token da conversa por voz da Maria (agente ElevenLabs). Antes era uma Edge Function do Supabase
 * aberta, sem autenticação; agora vive na API, atrás do JWT, e a chave do ElevenLabs fica só no
 * ambiente do servidor ({@code ELEVENLABS_API_KEY} e {@code ELEVENLABS_AGENT_ID}).
 *
 * <p>Sem as duas variáveis o endpoint responde 503 com código próprio, em vez de 500: o cliente
 * precisa distinguir "voz não configurada neste ambiente" de "falhou agora".
 */
@Service
public class VoiceService {

    private static final Logger log = LoggerFactory.getLogger(VoiceService.class);

    private final String apiKey;
    private final String agentId;
    private final RestClient elevenLabs;

    public VoiceService(@Value("${aura.voice.api-key:}") String apiKey,
                        @Value("${aura.voice.agent-id:}") String agentId,
                        @Value("${aura.voice.base-url:https://api.elevenlabs.io}") String baseUrl,
                        RestClient.Builder builder) {
        this.apiKey = apiKey;
        this.agentId = agentId;
        this.elevenLabs = builder.baseUrl(baseUrl).build();
    }

    public String conversationToken() {
        if (apiKey.isBlank() || agentId.isBlank()) {
            throw new ApiException("VOICE_NOT_CONFIGURED",
                    "A conversa por voz não está configurada neste ambiente.", HttpStatus.SERVICE_UNAVAILABLE);
        }
        try {
            @SuppressWarnings("unchecked")
            Map<String, Object> body = elevenLabs.get()
                    .uri("/v1/convai/conversation/token?agent_id={agentId}", agentId)
                    .header("xi-api-key", apiKey)
                    .retrieve()
                    .body(Map.class);
            Object token = body == null ? null : body.get("token");
            if (!(token instanceof String value) || value.isBlank()) {
                throw upstream("ElevenLabs respondeu sem token");
            }
            return value;
        } catch (ApiException e) {
            throw e;
        } catch (Exception e) {
            throw upstream("falha ao chamar o ElevenLabs: " + e.getClass().getSimpleName());
        }
    }

    private ApiException upstream(String reason) {
        // o motivo fica no log; a chave nunca entra nele nem na resposta
        log.warn("Token de voz indisponível: {}", reason);
        return new ApiException("VOICE_UPSTREAM_ERROR",
                "Não foi possível iniciar a conversa por voz agora.", HttpStatus.BAD_GATEWAY);
    }
}
