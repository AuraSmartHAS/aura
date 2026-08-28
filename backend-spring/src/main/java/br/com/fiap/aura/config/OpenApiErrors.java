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
import java.util.Set;
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

    /**
     * Rotas abertas: não faz sentido documentar erro de autorização nelas.
     *
     * <p>O SOS (C3) entra aqui em três das quatro rotas — o disparo, o cancelamento e a consulta de
     * estado são acessíveis sem sessão de propósito (regra 3). {@code /ack} <b>não</b> entra: aquela
     * exige autenticação e devolve 401/403 como qualquer outra.
     */
    private static final Set<String> PUBLICAS = Set.of(
            "/api/v1/health", "/api/v1/auth/login", "/api/v1/auth/signup", "/api/v1/auth/refresh",
            "/api/v1/emergencies", "/api/v1/emergencies/{emergencyId}",
            "/api/v1/emergencies/{emergencyId}/cancel");

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

    /** Consentimento LGPD (RN-001) — mesma resposta em toda rota que grava dado de saúde. */
    private static final String[] CONSENT = {"Consentimento LGPD não aceito (RN-001)",
            "CONSENT_REQUIRED", "Aceite a Política de Privacidade antes de registrar dados de saúde."};

    /** Erros de negócio: só aparecem nas rotas que realmente podem devolvê-los. */
    private static final Map<String, Map<String, String[]>> BY_PATH = Map.ofEntries(
            Map.entry("/api/v1/homes", Map.of("422", CONSENT)),
            Map.entry("/api/v1/signals", Map.of("422", CONSENT)),
            Map.entry("/api/v1/homes/{homeId}/medications", Map.of(
                    "400", new String[] {"Horário fora do formato \"HH:mm\"",
                            "VALIDATION_ERROR", "Corpo da requisição inválido."},
                    "422", CONSENT)),
            Map.entry("/api/v1/medications/{medId}", Map.of(
                    "400", new String[] {"Horário fora do formato \"HH:mm\"",
                            "VALIDATION_ERROR", "Corpo da requisição inválido."})),
            Map.entry("/api/v1/medications/{medId}/confirm", Map.of("422", CONSENT)),
            Map.entry("/api/v1/scores/recompute", Map.of(
                    "400", new String[] {"Dimensão fora da configuração do escore",
                            "UNKNOWN_DIMENSION", "Dimensão desconhecida: telepatia"},
                    "422", CONSENT)),
            Map.entry("/api/v1/recommendations", Map.of("422", new String[] {
                    "Escore não pertence à casa, sem produto para o risco, ou consentimento ausente",
                    "NO_PRODUCT", "Sem produto no catálogo para o risco 'fall_bathroom'."})),
            Map.entry("/api/v1/recommendations/{recommendationId}/approve", Map.of(
                    "409", new String[] {"Recomendação já aprovada", "CONFLICT", "Recomendação já aprovada."},
                    "422", new String[] {"Recomendação rejeitada não vira pedido (RN-022)",
                            "APPROVAL_REQUIRED", "Recomendação rejeitada não vira pedido."})),
            Map.entry("/api/v1/orders/{orderId}/advance", Map.of("409", new String[] {
                    "Pedido em estágio terminal", "CONFLICT", "Pedido em estágio terminal."})),
            Map.entry("/api/v1/auth/login", Map.of("401", new String[] {"Credenciais incorretas",
                    "INVALID_CREDENTIALS", "E-mail ou senha incorretos."})),
            Map.entry("/api/v1/auth/refresh", Map.of("401", new String[] {"Refresh token inválido ou de tipo errado",
                    "UNAUTHORIZED", "Token inválido."})),
            Map.entry("/api/v1/auth/signup", Map.of(
                    "400", new String[] {"Payload inválido — details traz o campo e o motivo",
                            "VALIDATION_ERROR", "Corpo da requisição inválido."},
                    "409", new String[] {"E-mail já cadastrado", "CONFLICT", "E-mail já cadastrado."})),
            Map.entry("/api/v1/catalog/{sku}", Map.of("409", new String[] {
                    "SKU já existe", "CONFLICT", "Já existe produto com o SKU LM-1566953614."})),
            Map.entry("/api/v1/notifications/test", Map.of("422", new String[] {
                    "Nenhum aparelho registrado para o destinatário, ou o Firebase recusou o aviso",
                    "PUSH_TOKEN_MISSING", "Nenhum aparelho registrado para receber o aviso. "
                            + "Faça login no app ou chame POST /api/v1/notifications/register-token antes."})),
            // SOS (C3): as três rotas abertas devolvem 404, e só 404 — nunca 422 por falta de
            // aparelho e nunca 429 por disparo repetido. Contenção aqui é resposta 201 declarando
            // que o aviso não pode ser prometido, porque negar um pedido de socorro com código de
            // erro empurra a decisão para uma tela que pode não saber o que fazer com ela.
            Map.entry("/api/v1/emergencies", Map.of("404", new String[] {
                    "O identificador da casa não corresponde a nenhuma casa",
                    "NOT_FOUND", "Casa não encontrada(a)."})),
            Map.entry("/api/v1/emergencies/{emergencyId}", Map.of("404", new String[] {
                    "Emergência inexistente", "NOT_FOUND", "Emergência não encontrada(a)."})),
            Map.entry("/api/v1/emergencies/{emergencyId}/cancel", Map.of("404", new String[] {
                    "Emergência inexistente", "NOT_FOUND", "Emergência não encontrada(a)."})),
            Map.entry("/api/v1/emergencies/{emergencyId}/ack", Map.of(
                    "404", new String[] {"Emergência inexistente",
                            "NOT_FOUND", "Emergência não encontrada(a)."},
                    "409", new String[] {"Emergência já encerrada (cancelada ou contida)",
                            "CONFLICT", "Esta emergência já foi encerrada (cancelled) e não aceita confirmação."})));

    @Bean
    public OpenApiCustomizer errorResponsesCustomizer() {
        return openApi -> {
            // registra o envelope de erro em components para as respostas referenciarem
            var resolved = ModelConverters.getInstance()
                    .resolveAsResolvedSchema(new AnnotatedType(ApiErrorResponse.class));
            resolved.referencedSchemas.forEach(openApi.getComponents()::addSchemas);

            openApi.getPaths().forEach((path, pathItem) -> pathItem.readOperations().forEach(operation -> {
                ApiResponses responses = operation.getResponses();
                // rota pública não devolve 401/403/404 de autorização — listar isso seria ruído
                if (PUBLICAS.contains(path)) {
                    put(responses, "500", COMMON.get("500"));
                } else {
                    COMMON.forEach((status, spec) -> put(responses, status, spec));
                }
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
