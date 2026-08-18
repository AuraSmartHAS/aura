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
        UserAccount user = users.save(UserAccount.builder()
                .email(req.email().toLowerCase())
                .passwordHash(encoder.encode(req.password()))
                .role(role)
                .name(req.name())
                .build());
        return new AuthDtos.SignupResponse(user.getId(),
                jwt.issueAccess(user.getId(), role), jwt.issueRefresh(user.getId(), role), role);
    }

    @Transactional(readOnly = true)
    public AuthDtos.TokenResponse login(AuthDtos.LoginRequest req) {
        UserAccount user = users.findByEmailIgnoreCase(req.email())
                .filter(u -> encoder.matches(req.password(), u.getPasswordHash()))
                .orElseThrow(() -> ApiException.unauthorized("INVALID_CREDENTIALS", "E-mail ou senha incorretos."));
        return new AuthDtos.TokenResponse(jwt.issueAccess(user.getId(), user.getRole()),
                user.getRole(), jwt.issueRefresh(user.getId(), user.getRole()));
    }

    @Transactional(readOnly = true)
    public AuthDtos.TokenResponse refresh(String refreshToken) {
        AuthPrincipal principal = jwt.parseRefresh(refreshToken);
        UserAccount user = users.findById(principal.userId())
                .orElseThrow(() -> ApiException.unauthorized("UNAUTHORIZED", "Usuário do token não existe mais."));
        return new AuthDtos.TokenResponse(jwt.issueAccess(user.getId(), user.getRole()),
                user.getRole(), jwt.issueRefresh(user.getId(), user.getRole()));
    }

    @Transactional(readOnly = true)
    public AuthDtos.MeResponse me(AuthPrincipal principal) {
        UserAccount user = require(principal.userId());
        return new AuthDtos.MeResponse(user.getId(), user.getRole(), user.getName(), user.getEmail(),
                consents.existsByUserId(user.getId()));
    }

    @Transactional
    public void changePassword(AuthPrincipal principal, AuthDtos.ChangePasswordRequest req) {
        UserAccount user = require(principal.userId());
        if (!encoder.matches(req.currentPassword(), user.getPasswordHash())) {
            throw ApiException.unauthorized("INVALID_CREDENTIALS", "Senha atual incorreta.");
        }
        user.setPasswordHash(encoder.encode(req.newPassword()));
    }

    @Transactional
    public void registerFcmToken(AuthPrincipal principal, String token) {
        require(principal.userId()).setFcmToken(token);
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
