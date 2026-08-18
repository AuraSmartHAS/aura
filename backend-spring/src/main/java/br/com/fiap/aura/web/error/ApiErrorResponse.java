package br.com.fiap.aura.web.error;

/** Envelope único de erro: {"error": {"code", "message", "details"}}. */
public record ApiErrorResponse(Body error) {

    public record Body(String code, String message, Object details) { }

    public static ApiErrorResponse of(String code, String message, Object details) {
        return new ApiErrorResponse(new Body(code, message, details));
    }
}
