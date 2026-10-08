package br.com.fiap.aura.security;

import br.com.fiap.aura.config.AuraProperties;
import br.com.fiap.aura.domain.UserAccount;
import br.com.fiap.aura.domain.enums.Role;
import br.com.fiap.aura.web.error.ApiException;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.Date;
import java.util.UUID;
import javax.crypto.SecretKey;
import org.springframework.stereotype.Service;

/**
 * Emissão e verificação dos tokens JWT (access e refresh).
 *
 * <p>Todo token carrega o claim {@code pwd}: um carimbo derivado do hash de senha vigente do
 * usuário no momento da emissão. Trocar a senha muda o hash (o BCrypt sorteia um sal novo a
 * cada codificação), então todo token emitido antes deixa de bater com a conta e é recusado —
 * revogação sem tabela de sessões nem migração. Token sem o claim (emitido antes desta regra)
 * também é recusado: aceitá-lo deixaria um refresh antigo roubado sobreviver à troca de senha;
 * o custo é um novo login, uma única vez, depois da atualização do servidor.
 */
@Service
public class JwtService {

    private static final String CLAIM_ROLE = "role";
    private static final String CLAIM_TYPE = "typ";
    private static final String CLAIM_PASSWORD_STAMP = "pwd";
    private static final String TYPE_ACCESS = "access";
    private static final String TYPE_REFRESH = "refresh";
    /** 16 caracteres base64url = 96 bits do SHA-256: basta para distinguir versões de senha. */
    private static final int STAMP_LENGTH = 16;

    private final SecretKey key;
    private final Duration accessTtl;
    private final Duration refreshTtl;

    /** Conteúdo de um token com assinatura, validade e tipo já conferidos. */
    public record ParsedToken(UUID userId, Role role, String passwordStamp) { }

    public JwtService(AuraProperties props) {
        this.key = Keys.hmacShaKeyFor(props.jwt().secret().getBytes(StandardCharsets.UTF_8));
        this.accessTtl = Duration.ofMinutes(props.jwt().accessTtlMinutes());
        this.refreshTtl = Duration.ofDays(props.jwt().refreshTtlDays());
    }

    public String issueAccess(UserAccount user) {
        return issue(user, TYPE_ACCESS, accessTtl);
    }

    public String issueRefresh(UserAccount user) {
        return issue(user, TYPE_REFRESH, refreshTtl);
    }

    private String issue(UserAccount user, String type, Duration ttl) {
        Instant now = Instant.now();
        return Jwts.builder()
                .subject(user.getId().toString())
                .claim(CLAIM_ROLE, user.getRole().value())
                .claim(CLAIM_TYPE, type)
                .claim(CLAIM_PASSWORD_STAMP, passwordStamp(user.getPasswordHash()))
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plus(ttl)))
                .signWith(key)
                .compact();
    }

    public ParsedToken parseAccess(String token) {
        return parse(token, TYPE_ACCESS);
    }

    public ParsedToken parseRefresh(String token) {
        return parse(token, TYPE_REFRESH);
    }

    /**
     * Recusa o token que não foi emitido para a senha atual da conta: senha trocada depois da
     * emissão, ou token de versão antiga, sem o carimbo.
     */
    public void requireCurrentPassword(ParsedToken token, UserAccount account) {
        String expected = passwordStamp(account.getPasswordHash());
        String actual = token.passwordStamp();
        if (actual == null || !MessageDigest.isEqual(expected.getBytes(StandardCharsets.UTF_8),
                actual.getBytes(StandardCharsets.UTF_8))) {
            throw ApiException.unauthorized("UNAUTHORIZED", "Sessão encerrada — entre novamente.");
        }
    }

    private ParsedToken parse(String token, String expectedType) {
        try {
            Claims claims = Jwts.parser().verifyWith(key).build().parseSignedClaims(token).getPayload();
            if (!expectedType.equals(claims.get(CLAIM_TYPE, String.class))) {
                throw ApiException.unauthorized("UNAUTHORIZED", "Token de tipo inesperado.");
            }
            return new ParsedToken(UUID.fromString(claims.getSubject()),
                    Role.from(claims.get(CLAIM_ROLE, String.class)),
                    claims.get(CLAIM_PASSWORD_STAMP, String.class));
        } catch (ExpiredJwtException e) {
            throw ApiException.unauthorized("TOKEN_EXPIRED", "Token expirado — use o refresh.");
        } catch (JwtException | IllegalArgumentException e) {
            throw ApiException.unauthorized("UNAUTHORIZED", "Token inválido.");
        }
    }

    /** SHA-256 truncado do hash armazenado: muda a cada troca de senha e não expõe o hash. */
    private static String passwordStamp(String passwordHash) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256")
                    .digest(passwordHash.getBytes(StandardCharsets.UTF_8));
            return Base64.getUrlEncoder().withoutPadding().encodeToString(digest).substring(0, STAMP_LENGTH);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 indisponível na JVM", e);
        }
    }
}
