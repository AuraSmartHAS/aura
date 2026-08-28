package br.com.fiap.aura.domain.converter;

import br.com.fiap.aura.domain.enums.EmergencyState;
import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

/**
 * Grava o estado da emergência como texto, para a coluna ser {@code varchar} <b>sem</b>
 * <i>check constraint</i> — mesmo padrão adotado no C0 ({@code HomeMemberRoleConverter}) e pela
 * mesma razão, documentada em {@link EmergencyState}.
 */
@Converter
public class EmergencyStateConverter implements AttributeConverter<EmergencyState, String> {

    @Override
    public String convertToDatabaseColumn(EmergencyState attribute) {
        return attribute == null ? null : attribute.name();
    }

    @Override
    public EmergencyState convertToEntityAttribute(String dbData) {
        return dbData == null || dbData.isBlank() ? null : EmergencyState.from(dbData);
    }
}
