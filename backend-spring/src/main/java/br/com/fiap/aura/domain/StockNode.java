package br.com.fiap.aura.domain;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.util.UUID;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Loja ou centro de distribuição que atende a casa (ship-from-store). */
@Entity
@Table(name = "stock_nodes")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class StockNode {

    @Id
    @GeneratedValue
    private UUID id;

    private String name;

    /** loja | cd */
    private String type;

    private double lat;

    private double lng;
}
