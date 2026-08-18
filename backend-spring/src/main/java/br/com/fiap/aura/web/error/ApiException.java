package br.com.fiap.aura.web.error;

import lombok.Getter;
import org.springframework.http.HttpStatus;

/** Erro de negócio com o código do contrato (mesmo catálogo do aura-server). */
@Getter
public class ApiException extends RuntimeException {

    private final String code;
    private final HttpStatus status;
    private final transient Object details;

    public ApiException(String code, String message, HttpStatus status, Object details) {
        super(message);
        this.code = code;
        this.status = status;
        this.details = details;
    }

    public ApiException(String code, String message, HttpStatus status) {
        this(code, message, status, null);
    }

    public static ApiException notFound(String what) {
        return new ApiException("NOT_FOUND", what + " não encontrado(a).", HttpStatus.NOT_FOUND);
    }

    public static ApiException forbidden() {
        return new ApiException("FORBIDDEN", "Acesso negado a este recurso.", HttpStatus.FORBIDDEN);
    }

    public static ApiException conflict(String message) {
        return new ApiException("CONFLICT", message, HttpStatus.CONFLICT);
    }

    public static ApiException unprocessable(String code, String message) {
        return new ApiException(code, message, HttpStatus.UNPROCESSABLE_ENTITY);
    }

    public static ApiException badRequest(String code, String message) {
        return new ApiException(code, message, HttpStatus.BAD_REQUEST);
    }

    public static ApiException unauthorized(String code, String message) {
        return new ApiException(code, message, HttpStatus.UNAUTHORIZED);
    }
}
