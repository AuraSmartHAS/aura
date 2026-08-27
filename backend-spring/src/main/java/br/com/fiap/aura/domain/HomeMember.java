package br.com.fiap.aura.domain;

import br.com.fiap.aura.domain.converter.HomeMemberRoleConverter;
import br.com.fiap.aura.domain.enums.HomeMemberRole;
import jakarta.persistence.Column;
import jakarta.persistence.Convert;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.Instant;
import java.util.UUID;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * Quem participa da casa e em que papel (C0). É o vínculo que faltava: até aqui a casa tinha um
 * único {@code ownerUserId}, então a própria paciente levava 403 na casa dela e "avisar os
 * cuidadores da casa" não tinha modelo de dados.
 *
 * <p>O vínculo <b>soma</b> acesso, nunca subtrai: o dono continua entrando pelo
 * {@code Home.ownerUserId} e quem não é dono nem vinculado continua levando 403 (RN-017).
 * Um par casa × usuário aparece uma vez só — o papel é do vínculo, não uma lista de papéis.
 */
@Entity
@Table(name = "home_members",
       uniqueConstraints = @UniqueConstraint(name = "uk_home_members_home_user",
                                             columnNames = {"home_id", "user_id"}))
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class HomeMember {

    @Id
    @GeneratedValue
    private UUID id;

    @Column(name = "home_id", nullable = false)
    private UUID homeId;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    /** Texto no banco, enum no Java — ver {@link HomeMemberRole} para o porquê. */
    @Convert(converter = HomeMemberRoleConverter.class)
    @Column(nullable = false, length = 20)
    private HomeMemberRole role;

    @Column(name = "created_at", nullable = false)
    @Builder.Default
    private Instant createdAt = Instant.now();
}
