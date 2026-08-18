package br.com.fiap.aura.security;

import br.com.fiap.aura.web.error.ApiException;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;

/** Acesso ao usuário autenticado a partir do contexto de segurança. */
@Component
public class CurrentUser {

    public AuthPrincipal require() {
        var auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !(auth.getPrincipal() instanceof AuthPrincipal principal)) {
            throw ApiException.unauthorized("UNAUTHORIZED", "Autenticação necessária.");
        }
        return principal;
    }
}
