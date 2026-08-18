package br.com.fiap.aura.web.dto;

import br.com.fiap.aura.domain.enums.Role;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.UUID;

public final class AuthDtos {

    private AuthDtos() { }

    public record SignupRequest(
            @NotBlank @Email @Schema(example = "nova.cuidadora@aura.com") String email,
            @NotBlank @Size(min = 6, message = "A senha precisa ter ao menos 6 caracteres")
            @Schema(example = "aura1234") String password,
            @Schema(example = "cuidadora") Role role,
            String name) { }

    public record SignupResponse(UUID userId,
            @Schema(example = "eyJhbGciOiJIUzM4NCJ9.eyJzdWIiOiI3MmEyMWVkMi0xNzhl...") String token,
            @Schema(example = "eyJhbGciOiJIUzM4NCJ9.eyJ0eXAiOiJyZWZyZXNoIiwic3Vi...") String refreshToken,
            Role role) { }

    public record LoginRequest(
            @NotBlank @Email @Schema(example = "ana@aura.com") String email,
            @NotBlank @Schema(example = "aura1234") String password) { }

    public record TokenResponse(
            @Schema(example = "eyJhbGciOiJIUzM4NCJ9.eyJzdWIiOiI3MmEyMWVkMi0xNzhl...") String token,
            @Schema(example = "cuidadora") Role role,
            @Schema(example = "eyJhbGciOiJIUzM4NCJ9.eyJ0eXAiOiJyZWZyZXNoIiwic3Vi...") String refreshToken) { }

    public record RefreshRequest(@NotBlank String refreshToken) { }

    public record MeResponse(UUID userId, Role role, String name, String email, boolean consentAccepted) { }

    public record ChangePasswordRequest(
            @NotBlank String currentPassword,
            @NotBlank @Size(min = 6) String newPassword) { }

    public record FcmTokenRequest(@NotBlank String fcmToken) { }

    public record ConsentRequest(
            @Schema(example = "2026-06", description = "Opcional — o default é a versão vigente da política")
            String version) { }

    public record ConsentResponse(Instant acceptedAt, String version) { }

    public record OkResponse(boolean ok) { }
}
