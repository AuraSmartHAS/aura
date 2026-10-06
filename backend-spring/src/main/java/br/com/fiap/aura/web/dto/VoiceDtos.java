package br.com.fiap.aura.web.dto;

public final class VoiceDtos {

    private VoiceDtos() { }

    /** Token de curta duração da sessão de voz; a chave do ElevenLabs nunca sai do servidor. */
    public record VoiceTokenResponse(String token) { }
}
