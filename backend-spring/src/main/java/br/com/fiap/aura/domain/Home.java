package br.com.fiap.aura.domain;

import br.com.fiap.aura.domain.converter.JsonMapConverter;
import jakarta.persistence.Column;
import jakarta.persistence.Convert;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Casa monitorada. O isolamento por usuário (RN-017) usa {@code ownerUserId}. */
@Entity
@Table(name = "homes")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Home {

    @Id
    @GeneratedValue
    private UUID id;

    @Column(name = "owner_user_id", nullable = false)
    private UUID ownerUserId;

    @Column(name = "patient_name", nullable = false)
    private String patientName;

    @Column(name = "birth_date")
    private LocalDate birthDate;

    private String label;

    private String cep;

    private String address;

    private Double lat;

    private Double lng;

    /** Itens de segurança da casa: {@code grab_bar_bathroom}, {@code slippery_floor}, ... */
    @Convert(converter = JsonMapConverter.class)
    @Column(name = "safety_checklist", length = 2000)
    @Builder.Default
    private Map<String, Object> safetyChecklist = new LinkedHashMap<>();

    @Column(name = "created_at", nullable = false)
    @Builder.Default
    private Instant createdAt = Instant.now();
}
