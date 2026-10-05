package br.com.fiap.aura.intelligence;

import java.nio.ByteBuffer;
import java.util.UUID;

/**
 * UUID ↔ RAW(16), no mesmo formato que o Hibernate usa para gravar as entidades: 16 bytes
 * big-endian, os 8 mais significativos primeiro. O driver Oracle não aceita {@code UUID} em
 * {@code setObject}; sem esta conversão a procedure receberia outra casa (ou nenhuma).
 */
public final class RawUuid {

    private RawUuid() { }

    public static byte[] toBytes(UUID id) {
        return ByteBuffer.allocate(16)
                .putLong(id.getMostSignificantBits())
                .putLong(id.getLeastSignificantBits())
                .array();
    }

    public static UUID fromBytes(byte[] raw) {
        if (raw == null) {
            return null;
        }
        if (raw.length != 16) {
            throw new IllegalArgumentException("RAW(16) esperado, veio com " + raw.length + " bytes");
        }
        ByteBuffer buffer = ByteBuffer.wrap(raw);
        return new UUID(buffer.getLong(), buffer.getLong());
    }
}
