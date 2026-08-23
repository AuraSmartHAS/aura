import { CommonModule } from '@angular/common';
import { Component, OnInit, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../core/api.service';
import { AuthService } from '../../core/auth.service';
import { errorMessage } from '../../core/error-message';
import { CatalogItem, Kpis } from '../../core/models';

/** Torre de Controle: KPIs da operação + manutenção do catálogo de acessibilidade. */
@Component({
  selector: 'app-admin',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './admin.html',
})
export class AdminPageComponent implements OnInit {
  private readonly api = inject(ApiService);
  private readonly auth = inject(AuthService);

  readonly kpis = signal<Kpis | null>(null);
  readonly catalog = signal<CatalogItem[]>([]);
  readonly error = signal<string | null>(null);
  readonly notice = signal<string | null>(null);
  readonly saving = signal(false);
  readonly isAdmin = this.auth.isAdmin;

  /** Formulário do produto — todos os campos com [(ngModel)]. */
  form: CatalogItem = this.emptyForm();
  editing = false;
  riskFilter = '';

  readonly riskTags = ['fall_bathroom', 'night_trips', 'mobility', 'cognition', 'environment'];

  readonly riskTagLabels: Record<string, string> = {
    fall_bathroom: 'Queda no banheiro',
    night_trips: 'Idas noturnas ao banheiro',
    mobility: 'Mobilidade',
    cognition: 'Cognição',
    environment: 'Ambiente',
  };

  ngOnInit(): void {
    this.loadCatalog();
    if (this.isAdmin()) {
      this.api.kpis().subscribe({
        next: (k) => this.kpis.set(k),
        error: (err) => this.error.set(errorMessage(err)),
      });
    }
  }

  loadCatalog(): void {
    this.api.catalog(this.riskFilter || undefined).subscribe({
      next: (items) => this.catalog.set(items),
      error: (err) => this.error.set(errorMessage(err)),
    });
  }

  riskLabel(tag: string | null): string {
    return (tag && this.riskTagLabels[tag]) ?? (tag ?? '');
  }

  edit(item: CatalogItem): void {
    this.form = { ...item };
    this.editing = true;
    this.notice.set(null);
  }

  reset(): void {
    this.form = this.emptyForm();
    this.editing = false;
  }

  save(): void {
    this.saving.set(true);
    this.error.set(null);
    const { sku, ...body } = this.form;

    this.api.saveProduct(sku, body, !this.editing).subscribe({
      next: () => {
        this.saving.set(false);
        this.flash(this.editing ? 'Produto atualizado.' : 'Produto cadastrado.');
        this.reset();
        this.loadCatalog();
      },
      error: (err) => {
        this.saving.set(false);
        this.error.set(errorMessage(err));
      },
    });
  }

  remove(item: CatalogItem): void {
    if (!confirm(`Remover ${item.name} do catálogo?`)) {
      return;
    }
    this.api.deleteProduct(item.sku).subscribe({
      next: () => {
        this.flash('Produto removido.');
        this.loadCatalog();
      },
      error: (err) => this.error.set(errorMessage(err)),
    });
  }

  percent(value: number): string {
    return `${Math.round(value * 100)}%`;
  }

  private emptyForm(): CatalogItem {
    return {
      sku: '',
      name: '',
      category: '',
      price: 0,
      installable: false,
      normRef: 'NBR 9050',
      riskTag: 'fall_bathroom',
      stockNearby: 0,
    };
  }

  private flash(message: string): void {
    this.notice.set(message);
    setTimeout(() => this.notice.set(null), 4000);
  }
}
