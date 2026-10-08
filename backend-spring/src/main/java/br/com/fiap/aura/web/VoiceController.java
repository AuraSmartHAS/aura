package br.com.fiap.aura.web;

import br.com.fiap.aura.service.VoiceService;
import br.com.fiap.aura.web.dto.VoiceDtos;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping(value = "/api/v1/voice", produces = MediaType.APPLICATION_JSON_VALUE)
@Tag(name = "10. Voz", description = "Sessão da conversa por voz com a Aura (ElevenLabs)")
public class VoiceController {

    private final VoiceService voice;

    public VoiceController(VoiceService voice) {
        this.voice = voice;
    }

    @GetMapping("/token")
    @Operation(summary = "Token de curta duração para abrir a conversa com o agente de voz",
            description = "503 VOICE_NOT_CONFIGURED sem ELEVENLABS_API_KEY/ELEVENLABS_AGENT_ID; "
                    + "502 VOICE_UPSTREAM_ERROR se o ElevenLabs falhar.")
    public VoiceDtos.VoiceTokenResponse token() {
        return new VoiceDtos.VoiceTokenResponse(voice.conversationToken());
    }
}
