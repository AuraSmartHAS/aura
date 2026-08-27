package br.com.fiap.aura.config;

import br.com.fiap.aura.domain.enums.SignalType;
import org.springframework.core.convert.converter.Converter;
import org.springframework.stereotype.Component;

/**
 * O contrato publica os tipos de sinal em minúsculas ("adherence") e é assim que a
 * API os devolve, mas o binding padrão do Spring só aceita o nome exato da constante.
 * Sem isto, {@code ?type=adherence} — o filtro que a tela de medicação usa para ver a
 * adesão — responderia 400 mesmo estando certo no OpenAPI.
 */
@Component
public class SignalTypeParamConverter implements Converter<String, SignalType> {

    @Override
    public SignalType convert(String source) {
        return SignalType.from(source);
    }
}
