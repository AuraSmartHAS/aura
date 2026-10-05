package br.com.fiap.aura.intelligence;

import java.util.UUID;

/**
 * Evento de domínio: uma leitura nova da casa foi gravada (sinal pela API ou confirmação de dose).
 * Quem publica não sabe que existe Oracle; quem escuta ({@link AlertasAoRegistrarLeitura}) decide.
 */
public record LeituraRegistrada(UUID homeId) { }
