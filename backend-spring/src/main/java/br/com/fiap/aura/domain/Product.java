package br.com.fiap.aura.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Item do catálogo de acessibilidade (base NBR 9050) que a Care-Chain pode recomendar. */
@Entity
@Table(name = "products")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Product {

    @Id
    private String sku;

    @Column(nullable = false)
    private String name;

    @Column(nullable = false)
    private String category;

    @Column(nullable = false, precision = 10, scale = 2)
    private BigDecimal price;

    @Column(nullable = false)
    @Builder.Default
    private boolean installable = false;

    @Column(name = "norm_ref")
    private String normRef;

    /** Risco que o item mitiga: fall_bathroom, night_trips, mobility, cognition, environment. */
    @Column(name = "risk_tag")
    private String riskTag;

    /**
     * Produto de referência da curadoria para o seu risco — é o que a recomendação escolhe
     * primeiro. Sem isso, um catálogo grande faria a régua "instalável mais caro" recomendar
     * o item mais premium da prateleira em vez do kit de entrada validado com a persona.
     */
    @Column(nullable = false)
    @Builder.Default
    private boolean featured = false;

    @Column(name = "stock_nearby", nullable = false)
    @Builder.Default
    private int stockNearby = 0;
}
