package br.com.fiap.aura.security;

import br.com.fiap.aura.domain.enums.Role;
import java.util.UUID;

/** Usuário autenticado, extraído do JWT — sem sessão no servidor (stateless). */
public record AuthPrincipal(UUID userId, Role role) {

    public boolean isAdmin() {
        return role == Role.ADMIN;
    }
}
