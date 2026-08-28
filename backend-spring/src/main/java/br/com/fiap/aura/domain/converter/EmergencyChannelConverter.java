package br.com.fiap.aura.domain.converter;

import br.com.fiap.aura.domain.enums.EmergencyChannel;
import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

/** Canal do pedido de socorro como texto puro — ver {@link EmergencyStateConverter}. */
@Converter
public class EmergencyChannelConverter implements AttributeConverter<EmergencyChannel, String> {

    @Override
    public String convertToDatabaseColumn(EmergencyChannel attribute) {
        return attribute == null ? null : attribute.name();
    }

    @Override
    public EmergencyChannel convertToEntityAttribute(String dbData) {
        return dbData == null || dbData.isBlank() ? null : EmergencyChannel.from(dbData);
    }
}
