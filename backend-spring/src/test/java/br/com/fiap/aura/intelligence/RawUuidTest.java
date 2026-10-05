package br.com.fiap.aura.intelligence;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.HexFormat;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class RawUuidTest {

    @Test
    void idaEVoltaPreservaOUuid() {
        UUID id = UUID.randomUUID();
        assertThat(RawUuid.fromBytes(RawUuid.toBytes(id))).isEqualTo(id);
    }

    @Test
    void bytesSaoOMesmoTextoQueORawtohexDoOracle() {
        // É o que permite casar RAWTOHEX(id) no PL/SQL com o UUID que o Java grava no JSON.
        UUID id = UUID.fromString("3f2a8c10-1b2c-4d5e-8f90-a1b2c3d4e5f6");
        assertThat(HexFormat.of().formatHex(RawUuid.toBytes(id))).isEqualTo("3f2a8c101b2c4d5e8f90a1b2c3d4e5f6");
    }

    @Test
    void recusaRawDeTamanhoErrado() {
        assertThat(RawUuid.fromBytes(null)).isNull();
        assertThatThrownBy(() -> RawUuid.fromBytes(new byte[8])).isInstanceOf(IllegalArgumentException.class);
    }
}
