import { CommonModule } from '@angular/common';
import { Component, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { ApiService } from '../../core/api.service';
import { CatalogItem } from '../../core/models';

/**
 * Página de parceiros. O Aura não vende nada: ele qualifica a necessidade dentro de casa e
 * entrega a demanda a quem vende. Esta tela mostra quem já está no catálogo e abre a porta
 * para os demais — foi o recorte que a própria Leroy indicou na 3ª mentoria, em que a Leroy
 * aparece como um parceiro entre fornecedores, em vez de integração sistêmica.
 */
@Component({
  selector: 'app-partners',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './partners.html',
})
export class PartnersPageComponent {
  private readonly api = inject(ApiService);

  readonly products = signal<CatalogItem[]>([]);
  readonly loading = signal(true);
  readonly error = signal<string | null>(null);

  constructor() {
    this.api.catalog().subscribe({
      next: (list) => {
        this.products.set(list);
        this.loading.set(false);
      },
      error: () => {
        this.error.set('Não foi possível carregar o catálogo agora.');
        this.loading.set(false);
      },
    });
  }

  /** Um parceiro por nome, com quantos itens ele traz. Item sem parceiro não vira linha. */
  partners(): { name: string; items: number }[] {
    const count = new Map<string, number>();
    for (const p of this.products()) {
      if (!p.partner) {
        continue;
      }
      count.set(p.partner, (count.get(p.partner) ?? 0) + 1);
    }
    return [...count.entries()]
      .map(([name, items]) => ({ name, items }))
      .sort((a, b) => b.items - a.items);
  }

  /** Itens sem parceiro: a tela não esconde o que ainda não tem quem venda. */
  unassigned(): number {
    return this.products().filter((p) => !p.partner).length;
  }
}
