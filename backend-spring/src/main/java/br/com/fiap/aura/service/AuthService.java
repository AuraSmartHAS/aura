package br.com.fiap.aura.service;

import br.com.fiap.aura.domain.Consent;
import br.com.fiap.aura.domain.UserAccount;
import br.com.fiap.aura.domain.enums.Role;
import br.com.fiap.aura.repository.ConsentRepository;
import br.com.fiap.aura.repository.UserAccountRepository;
import br.com.fiap.aura.security.AuthPrincipal;
import br.com.fiap.aura.security.JwtService;
import br.com.fiap.aura.web.dto.AuthDtos;
import br.com.fiap.aura.web.error.ApiException;
import java.util.UUID;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {

    /** Versão vigente da política aceita no gate LGPD. */
    public static final String CONSENT_VERSION = "2026-06";

    private final UserAccountRepository users;
    private final ConsentRepository consents;
    private final PasswordEncoder encoder;
    private final JwtService jwt;

    public AuthService(UserAccountRepository users, ConsentRepository consents,
                       PasswordEncoder encoder, JwtService jwt) {
        this.users = users;
        this.consents = consents;
        this.encoder = encoder;
        this.jwt = jwt;
    }

    @Transactional
    public AuthDtos.SignupResponse signup(AuthDtos.SignupRequest req) {
        if (users.existsByEmailIgnoreCase(req.email())) {
            throw ApiException.conflict("E-mail já cadastrado.");
        }
        Role role = req.role() == null ? Role.CUIDADORA : req.role();
        if (role == Role.ADMIN) {
            // A rota é pública; aceitar ADMIN aqui entregaria uma credencial de operação a quem
            // ainda não provou ter qualquer autorização administrativa.
            throw ApiException.forbidden();
        }
        UserAccount user = users.save(UserAccount.builder()
                .email(req.email().toLowerCase())
                .passwordHash(encoder.encode(req.password()))
                .role(role)
                .name(req.name())
                .build());
        return new AuthDtos.SignupResponse(user.getId(),
                jwt.issueAccess(user), jwt.issueRefresh(user), role);
    }

    /** Cria uma conta administrativa sem devolver credenciais ao solicitante. */
    @Transactional
    public AuthDtos.AdminProvisionResponse provisionAdmin(AuthPrincipal principal,
                                                           AuthDtos.AdminProvisionRequest req) {
        UserAccount requester = users.findById(principal.userId()).orElseThrow(() ->
                ApiException.unauthorized("UNAUTHORIZED", "Usuário do token não existe mais."));
        if (requester.getRole() != Role.ADMIN) {
            throw ApiException.forbidden();
        }
        if (users.existsByEmailIgnoreCase(req.email())) {
            throw ApiException.conflict("E-mail já cadastrado.");
        }
        UserAccount user = users.save(UserAccount.builder()
                .email(req.email().toLowerCase())
                .passwordHash(encoder.encode(req.password()))
                .role(Role.ADMIN)
                .name(req.name())
                .build());
        return new AuthDtos.AdminProvisionResponse(user.getId(), Role.ADMIN.value());
    }

    @Transactional(readOnly = true)
    public AuthDtos.TokenResponse login(AuthDtos.LoginRequest req) {
        UserAccount user = users.findByEmailIgnoreCase(req.email())
                .filter(u -> encoder.matches(req.password(), u.getPasswordHash()))
                .orElseThrow(() -> ApiException.unauthorized("INVALID_CREDENTIALS", "E-mail ou senha incorretos."));
        return tokens(user);
    }

    @Transactional(readOnly = true)
    public AuthDtos.TokenResponse refresh(String refreshToken) {
        JwtService.ParsedToken token = jwt.parseRefresh(refreshToken);
        UserAccount user = users.findById(token.userId())
                .orElseThrow(() -> ApiException.unauthorized("UNAUTHORIZED", "Usuário do token não existe mais."));
        // Refresh emitido antes da última troca de senha não renova mais a sessão.
        jwt.requireCurrentPassword(token, user);
        return tokens(user);
    }

    @Transactional(readOnly = true)
    public AuthDtos.MeResponse me(AuthPrincipal principal) {
        UserAccount user = require(principal.userId());
        return new AuthDtos.MeResponse(user.getId(), user.getRole(), user.getName(), user.getEmail(),
                consents.existsByUserId(user.getId()));
    }

    /**
     * Troca a senha e devolve um par de tokens novo. O hash muda, então todo access e refresh
     * emitido antes deixa de valer; o chamador segue logado com o par devolvido.
     */
    @Transactional
    public AuthDtos.TokenResponse changePassword(AuthPrincipal principal, AuthDtos.ChangePasswordRequest req) {
        UserAccount user = require(principal.userId());
        if (!encoder.matches(req.currentPassword(), user.getPasswordHash())) {
            throw ApiException.unauthorized("INVALID_CREDENTIALS", "Senha atual incorreta.");
        }
        user.setPasswordHash(encoder.encode(req.newPassword()));
        return tokens(user);
    }

    private AuthDtos.TokenResponse tokens(UserAccount user) {
        return new AuthDtos.TokenResponse(jwt.issueAccess(user), user.getRole(), jwt.issueRefresh(user));
    }

    /**
     * Um aparelho é de uma pessoa só. O celular em que a Ana saiu e a Maria entrou continua com o
     * mesmo token FCM; sem tirar o token da Ana, o SOS endereçado a ela apitaria na mão da Maria.
     */
    @Transactional
    public void registerFcmToken(AuthPrincipal principal, String token) {
        users.findByFcmToken(token).stream()
                .filter(u -> !u.getId().equals(principal.userId()))
                .forEach(u -> u.setFcmToken(null));
        require(principal.userId()).setFcmToken(token);
    }

    /**
     * Desregistro no logout. Com o token informado, só apaga se ainda for o registrado: o logout
     * atrasado de um aparelho antigo não pode desligar o aviso do aparelho em que a pessoa entrou
     * depois. Sem token, apaga o que houver. Idempotente nos dois casos.
     */
    @Transactional
    public void unregisterFcmToken(AuthPrincipal principal, String token) {
        UserAccount user = require(principal.userId());
        if (token == null || token.isBlank() || token.equals(user.getFcmToken())) {
            user.setFcmToken(null);
        }
    }

    @Transactional
    public AuthDtos.ConsentResponse acceptConsent(AuthPrincipal principal, String version) {
        require(principal.userId());
        String v = (version == null || version.isBlank()) ? CONSENT_VERSION : version;
        Consent consent = consents.save(Consent.builder().userId(principal.userId()).version(v).build());
        return new AuthDtos.ConsentResponse(consent.getAcceptedAt(), consent.getVersion());
    }

    /** Gate LGPD (RN-001): nenhum dado de saúde entra sem aceite. Admin é isento. */
    @Transactional(readOnly = true)
    public void requireConsent(AuthPrincipal principal) {
        if (principal.isAdmin()) {
            return;
        }
        if (!consents.existsByUserId(principal.userId())) {
            throw ApiException.unprocessable("CONSENT_REQUIRED",
                    "Aceite a Política de Privacidade antes de registrar dados de saúde.");
        }
    }

    private UserAccount require(UUID userId) {
        return users.findById(userId).orElseThrow(() -> ApiException.notFound("Usuário"));
    }
}
