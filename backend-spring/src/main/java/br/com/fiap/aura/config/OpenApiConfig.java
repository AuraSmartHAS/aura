package br.com.fiap.aura.config;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.info.License;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** Documentação viva da API (Swagger UI em /swagger-ui.html). */
@Configuration
public class OpenApiConfig {

    private static final String SCHEME = "bearerAuth";

    @Bean
    public OpenAPI auraOpenApi() {
        return new OpenAPI()
                .info(new Info()
                        .title("AURA Care-Chain API")
                        .version("1.0.0")
                        .description("""
                                API REST do AURA Care-Chain — assistente de saúde domiciliar voice-first
                                para idosos com Parkinson, com cadeia logística de segurança da casa.

                                Consumida por três clientes: app Flutter (Android/iOS/Web),
                                app React Native e painel administrativo Angular.

                                Regras de ouro: nunca prescreve nem diagnostica, o escore é sempre
                                explicável (fatores + pesos) e nenhum dado de saúde é gravado sem
                                consentimento LGPD.
                                """)
                        .contact(new Contact().name("Equipe AURA — FIAP Smart HAS"))
                        .license(new License().name("Uso acadêmico — FIAP 2026")))
                .addSecurityItem(new SecurityRequirement().addList(SCHEME))
                .components(new Components().addSecuritySchemes(SCHEME,
                        new SecurityScheme()
                                .type(SecurityScheme.Type.HTTP)
                                .scheme("bearer")
                                .bearerFormat("JWT")
                                .description("Token obtido em POST /api/v1/auth/login")));
    }
}
