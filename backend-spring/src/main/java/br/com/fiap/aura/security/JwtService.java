package br.com.fiap.aura.security;

import br.com.fiap.aura.config.AuraProperties;
import br.com.fiap.aura.domain.enums.Role;
import br.com.fiap.aura.web.error.ApiException;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.Date;
import java.util.UUID;
import javax.crypto.SecretKey;
import org.springframework.stereotype.Service;

/** Emissão e verificação dos tokens JWT (access e refresh). */
@Service
public class JwtService {

    private static final String CLAIM_ROLE = "role";
    private static final String CLAIM_TYPE = "typ";
    private static final String TYPE_ACCESS = "access";
    private static final String TYPE_REFRESH = "refresh";

    private final SecretKey key;
    private final Duration accessTtl;
    private final Duration refreshTtl;

    public JwtService(AuraProperties props) {
        this.key = Keys.hmacShaKeyFor(props.jwt().secret().getBytes(StandardCharsets.UTF_8));
        this.accessTtl = Duration.ofMinutes(props.jwt().accessTtlMinutes());
        this.refreshTtl = Duration.ofDays(props.jwt().refreshTtlDays());
    }

    public String issueAccess(UUID userId, Role role) {
        return issue(userId, role, TYPE_ACCESS, accessTtl);
    }

    public String issueRefresh(UUID userId, Role role) {
        return issue(userId, role, TYPE_REFRESH, refreshTtl);
    }

    private String issue(UUID userId, Role role, String type, Duration ttl) {
        Instant now = Instant.now();
        return Jwts.builder()
                .subject(userId.toString())
                .claim(CLAIM_ROLE, role.value())
                .claim(CLAIM_TYPE, type)
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plus(ttl)))
                .signWith(key)
                .compact();
    }

    public AuthPrincipal parseAccess(String token) {
        return parse(token, TYPE_ACCESS);
    }

    public AuthPrincipal parseRefresh(String token) {
        return parse(token, TYPE_REFRESH);
    }

    private AuthPrincipal parse(String token, String expectedType) {
        try {
            Claims claims = Jwts.parser().verifyWith(key).build().parseSignedClaims(token).getPayload();
            if (!expectedType.equals(claims.get(CLAIM_TYPE, String.class))) {
                throw ApiException.unauthorized("UNAUTHORIZED", "Token de tipo inesperado.");
            }
            return new AuthPrincipal(UUID.fromString(claims.getSubject()),
                    Role.from(claims.get(CLAIM_ROLE, String.class)));
        } catch (ExpiredJwtException e) {
            throw ApiException.unauthorized("TOKEN_EXPIRED", "Token expirado — use o refresh.");
        } catch (JwtException | IllegalArgumentException e) {
            throw ApiException.unauthorized("UNAUTHORIZED", "Token inválido.");
        }
    }
}
