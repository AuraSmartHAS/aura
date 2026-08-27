package br.com.fiap.aura.domain.enums;

/**
 * Papel de um usuário <b>dentro de uma casa</b> (tabela {@code home_members}).
 *
 * <p>Não se confunde com {@link Role}, que é o RBAC da conta e vale para a API inteira: o papel
 * da conta diz o que a pessoa é no sistema, este diz o que ela é <i>naquela casa</i>. A mesma
 * cuidadora pode ser dona da casa de uma paciente e apenas cuidadora na casa de outra, então o
 * papel pertence ao vínculo, não à conta — reusar {@code Role} aqui traria {@code ADMIN} para
 * dentro da casa e ainda assim não teria "dono".
 *
 * <p>Convenção que o escalonamento do SOS (C3) vai usar: "os cuidadores da casa" são os vínculos
 * {@link #DONO} e {@link #CUIDADORA} — quem recebe o aviso. {@link #PACIENTE} é quem dispara.
 *
 * <p><b>Persistido como texto</b> (ver {@code HomeMemberRoleConverter}), e não com
 * {@code @Enumerated(STRING)}: o projeto não tem Flyway nem Liquibase e o perfil {@code postgres}
 * roda com {@code ddl-auto: update}, que cria tabela nova mas não altera <i>check constraint</i>
 * existente. Com {@code @Enumerated} o Hibernate geraria um check com os valores de hoje e o
 * primeiro papel novo (um profissional de saúde, um vizinho de plantão) quebraria em Postgres
 * passando 100% verde no H2, que recria o schema a cada boot. Coluna de texto validada na
 * aplicação deixa a evolução livre.
 */
public enum HomeMemberRole {
    DONO, CUIDADORA, PACIENTE;

    /** Validação na entrada: valor fora da lista é erro de programação, não papel desconhecido. */
    public static HomeMemberRole from(String raw) {
        return HomeMemberRole.valueOf(raw.trim().toUpperCase());
    }
}
