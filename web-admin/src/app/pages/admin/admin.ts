import { CommonModule } from '@angular/common';
import { Component, DestroyRef, OnInit, inject, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { FormsModule } from '@angular/forms';
import { EMPTY, catchError, forkJoin, interval, startWith, switchMap } from 'rxjs';
import { ApiService } from '../../core/api.service';
import { AuthService } from '../../core/auth.service';
import { errorMessage } from '../../core/error-message';
import { STAGE_LABELS } from '../../core/labels';
import { CatalogItem, Kpis, OpsOrder } from '../../core/models';

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
  private readonly destroyRef = inject(DestroyRef);

  readonly kpis = signal<Kpis | null>(null);
  readonly carteira = signal<OpsOrder[]>([]);
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

  readonly stageLabels = STAGE_LABELS;

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
      // NOC não espera F5: KPIs e carteira se renovam juntos a cada 10s. Num tick com erro
      // o último valor fica na tela — o banner só aparece se nunca houve KPI carregado.
      interval(10_000)
        .pipe(
          startWith(0),
          switchMap(() =>
            forkJoin({ kpis: this.api.kpis(), carteira: this.api.opsOrders() }).pipe(
              catchError((err) => {
                if (!this.kpis()) {
                  this.error.set(errorMessage(err));
                }
                return EMPTY;
              }),
            ),
          ),
          takeUntilDestroyed(this.destroyRef),
        )
        .subscribe(({ kpis, carteira }) => {
          this.kpis.set(kpis);
          this.carteira.set(carteira);
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
