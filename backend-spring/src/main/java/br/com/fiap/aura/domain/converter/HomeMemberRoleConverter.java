package br.com.fiap.aura.domain.converter;

import br.com.fiap.aura.domain.enums.HomeMemberRole;
import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

/**
 * Grava o papel do vínculo como texto simples. O conversor existe para que a coluna seja
 * {@code varchar} sem <i>check constraint</i> — a razão está documentada em {@link HomeMemberRole}.
 */
@Converter
public class HomeMemberRoleConverter implements AttributeConverter<HomeMemberRole, String> {

    @Override
    public String convertToDatabaseColumn(HomeMemberRole attribute) {
        return attribute == null ? null : attribute.name();
    }

    @Override
    public HomeMemberRole convertToEntityAttribute(String dbData) {
        return dbData == null || dbData.isBlank() ? null : HomeMemberRole.from(dbData);
    }
}
