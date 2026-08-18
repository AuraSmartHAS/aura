package br.com.fiap.aura.web;

import br.com.fiap.aura.security.CurrentUser;
import br.com.fiap.aura.service.AuthService;
import br.com.fiap.aura.service.LgpdService;
import br.com.fiap.aura.web.dto.AuthDtos;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.security.SecurityRequirements;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping(value = "/api/v1", produces = MediaType.APPLICATION_JSON_VALUE)
@Tag(name = "1. Autenticação & LGPD", description = "Cadastro, login, refresh e aceite de consentimento")
public class AuthController {

    private final AuthService auth;
    private final LgpdService lgpd;
    private final CurrentUser currentUser;

    public AuthController(AuthService auth, LgpdService lgpd, CurrentUser currentUser) {
        this.auth = auth;
        this.lgpd = lgpd;
        this.currentUser = currentUser;
    }

    @PostMapping("/auth/signup")
    @ResponseStatus(HttpStatus.CREATED)
    @SecurityRequirements
    @Operation(summary = "Cria conta (paciente, cuidadora, profissional ou admin)")
    public AuthDtos.SignupResponse signup(@Valid @RequestBody AuthDtos.SignupRequest req) {
        return auth.signup(req);
    }

    @PostMapping("/auth/login")
    @SecurityRequirements
    @Operation(summary = "Autentica e devolve o par de tokens (access + refresh)")
    public AuthDtos.TokenResponse login(@Valid @RequestBody AuthDtos.LoginRequest req) {
        return auth.login(req);
    }

    @PostMapping("/auth/refresh")
    @SecurityRequirements
    @Operation(summary = "Troca o refresh token por um novo access token")
    public AuthDtos.TokenResponse refresh(@Valid @RequestBody AuthDtos.RefreshRequest req) {
        return auth.refresh(req.refreshToken());
    }

    @GetMapping("/auth/me")
    @SecurityRequirement(name = "bearerAuth")
    @Operation(summary = "Dados do usuário autenticado, incluindo se já aceitou a política")
    public AuthDtos.MeResponse me() {
        return auth.me(currentUser.require());
    }

    @DeleteMapping("/auth/me")
    @Operation(summary = "Exclui a conta e todos os dados do titular (LGPD, art. 18)")
    public AuthDtos.OkResponse deleteAccount() {
        lgpd.deleteAccount(currentUser.require());
        return new AuthDtos.OkResponse(true);
    }

    @PostMapping("/auth/password")
    @Operation(summary = "Troca a senha do usuário autenticado")
    public AuthDtos.OkResponse changePassword(@Valid @RequestBody AuthDtos.ChangePasswordRequest req) {
        auth.changePassword(currentUser.require(), req);
        return new AuthDtos.OkResponse(true);
    }

    @PostMapping("/notifications/register-token")
    @Operation(summary = "Registra o token FCM do dispositivo para receber push")
    public AuthDtos.OkResponse registerFcm(@Valid @RequestBody AuthDtos.FcmTokenRequest req) {
        auth.registerFcmToken(currentUser.require(), req.fcmToken());
        return new AuthDtos.OkResponse(true);
    }

    @PostMapping("/consent")
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Aceite da política LGPD — gate obrigatório antes de qualquer dado de saúde")
    public AuthDtos.ConsentResponse consent(@RequestBody(required = false) AuthDtos.ConsentRequest req) {
        return auth.acceptConsent(currentUser.require(), req == null ? null : req.version());
    }
}
