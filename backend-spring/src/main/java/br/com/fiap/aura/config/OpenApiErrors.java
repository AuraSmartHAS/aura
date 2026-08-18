package br.com.fiap.aura.config;

import br.com.fiap.aura.web.error.ApiErrorResponse;
import io.swagger.v3.core.converter.AnnotatedType;
import io.swagger.v3.core.converter.ModelConverters;
import io.swagger.v3.oas.models.examples.Example;
import io.swagger.v3.oas.models.media.Content;
import io.swagger.v3.oas.models.media.MediaType;
import io.swagger.v3.oas.models.media.Schema;
import io.swagger.v3.oas.models.responses.ApiResponse;
import io.swagger.v3.oas.models.responses.ApiResponses;
import java.util.LinkedHashMap;
import java.util.Map;
import org.springdoc.core.customizers.OpenApiCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Documenta no Swagger as respostas de erro que qualquer rota pode devolver.
 * Anotar 30 métodos à mão sairia desatualizado no primeiro endpoint novo —
 * aqui a documentação nasce do mesmo envelope que o GlobalExceptionHandler produz.
 */
@Configuration
public class OpenApiErrors {

    private static final String ERROR_REF = "#/components/schemas/ApiErrorResponse";
    private static final String JSON = "application/json";

    /** Erros possíveis em praticamente qualquer rota autenticada. */
    private static final Map<String, String[]> COMMON = Map.of(
            "401", new String[] {"Token ausente, inválido ou expirado — ou credenciais incorretas no login",
                                 "UNAUTHORIZED", "Autenticação necessária."},
            "403", new String[] {"Papel sem permissão (RBAC) ou recurso de outro paciente (isolamento)",
                                 "FORBIDDEN", "Acesso negado a este recurso."},
            "404", new String[] {"Recurso inexistente",
                                 "NOT_FOUND", "Casa não encontrada(a)."},
            "500", new String[] {"Falha inesperada — a mensagem interna fica no log do servidor",
                                 "INTERNAL_ERROR", "Erro interno."});

    /** Erros de negócio: só aparecem nas rotas que realmente podem devolvê-los. */
    private static final Map<String, Map<String, String[]>> BY_PATH = Map.of(
            "/api/v1/homes", Map.of("422", new String[] {"Consentimento LGPD não aceito (RN-001)",
                    "CONSENT_REQUIRED", "Aceite a Política de Privacidade antes de registrar dados de saúde."}),
            "/api/v1/signals", Map.of("422", new String[] {"Consentimento LGPD não aceito (RN-001)",
                    "CONSENT_REQUIRED", "Aceite a Política de Privacidade antes de registrar dados de saúde."}),
            "/api/v1/scores/recompute", Map.of(
                    "400", new String[] {"Dimensão fora da configuração do escore",
                            "UNKNOWN_DIMENSION", "Dimensão desconhecida: telepatia"},
                    "422", new String[] {"Consentimento LGPD não aceito (RN-001)",
                            "CONSENT_REQUIRED", "Aceite a Política de Privacidade antes de registrar dados de saúde."}),
            "/api/v1/recommendations", Map.of("422", new String[] {
                    "Escore não pertence à casa, sem produto para o risco, ou consentimento ausente",
                    "NO_PRODUCT", "Sem produto no catálogo para o risco 'fall_bathroom'."}),
            "/api/v1/recommendations/{recommendationId}/approve", Map.of(
                    "409", new String[] {"Recomendação já aprovada", "CONFLICT", "Recomendação já aprovada."},
                    "422", new String[] {"Recomendação rejeitada não vira pedido (RN-022)",
                            "APPROVAL_REQUIRED", "Recomendação rejeitada não vira pedido."}),
            "/api/v1/orders/{orderId}/advance", Map.of("409", new String[] {
                    "Pedido em estágio terminal", "CONFLICT", "Pedido em estágio terminal."}),
            "/api/v1/auth/signup", Map.of(
                    "400", new String[] {"Payload inválido — details traz o campo e o motivo",
                            "VALIDATION_ERROR", "Corpo da requisição inválido."},
                    "409", new String[] {"E-mail já cadastrado", "CONFLICT", "E-mail já cadastrado."}),
            "/api/v1/catalog/{sku}", Map.of("409", new String[] {
                    "SKU já existe", "CONFLICT", "Já existe produto com o SKU LM-1566953614."}));

    @Bean
    public OpenApiCustomizer errorResponsesCustomizer() {
        return openApi -> {
            // registra o envelope de erro em components para as respostas referenciarem
            var resolved = ModelConverters.getInstance()
                    .resolveAsResolvedSchema(new AnnotatedType(ApiErrorResponse.class));
            resolved.referencedSchemas.forEach(openApi.getComponents()::addSchemas);

            openApi.getPaths().forEach((path, pathItem) -> pathItem.readOperations().forEach(operation -> {
                ApiResponses responses = operation.getResponses();
                COMMON.forEach((status, spec) -> put(responses, status, spec));
                BY_PATH.getOrDefault(path, Map.of()).forEach((status, spec) -> put(responses, status, spec));
            }));
        };
    }

    private void put(ApiResponses responses, String status, String[] spec) {
        if (responses.containsKey(status)) {
            return;
        }
        // objeto, não string: assim o Swagger/Redoc renderiza JSON formatado em vez de texto escapado
        Map<String, Object> corpo = new LinkedHashMap<>();
        corpo.put("code", spec[1]);
        corpo.put("message", spec[2]);
        corpo.put("details", null);
        Example example = new Example().value(Map.of("error", corpo));

        responses.addApiResponse(status, new ApiResponse()
                .description(spec[0])
                .content(new Content().addMediaType(JSON, new MediaType()
                        .schema(new Schema<>().$ref(ERROR_REF))
                        .addExamples(spec[1], example))));
    }
}
