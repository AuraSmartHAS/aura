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
            @NotBlank @Email String email,
            @NotBlank @Size(min = 6, message = "A senha precisa ter ao menos 6 caracteres") String password,
            @Schema(example = "cuidadora") Role role,
            String name) { }

    public record SignupResponse(UUID userId, String token, String refreshToken, Role role) { }

    public record LoginRequest(
            @NotBlank @Email String email,
            @NotBlank String password) { }

    public record TokenResponse(String token, Role role, String refreshToken) { }

    public record RefreshRequest(@NotBlank String refreshToken) { }

    public record MeResponse(UUID userId, Role role, String name, String email, boolean consentAccepted) { }

    public record ChangePasswordRequest(
            @NotBlank String currentPassword,
            @NotBlank @Size(min = 6) String newPassword) { }

    public record FcmTokenRequest(@NotBlank String fcmToken) { }

    public record ConsentRequest(String version) { }

    public record ConsentResponse(Instant acceptedAt, String version) { }

    public record OkResponse(boolean ok) { }
}
