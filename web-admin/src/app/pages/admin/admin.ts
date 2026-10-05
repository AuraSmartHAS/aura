import { CommonModule } from '@angular/common';
import { Component, DestroyRef, OnInit, inject, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { FormsModule } from '@angular/forms';
import { EMPTY, catchError, forkJoin, interval, of, startWith, switchMap } from 'rxjs';
import { ApiService } from '../../core/api.service';
import { AuthService } from '../../core/auth.service';
import { errorMessage } from '../../core/error-message';
import { RISK_TAG_LABELS, diaMes, percentualOuSemDados, riskTagLabel, variacaoComSinal } from '../../core/labels';
import { CatalogItem, IndicadoresResponse, Kpis } from '../../core/models';

/** Operação: indicadores das casas + manutenção do catálogo de acessibilidade. */
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
  /** Indicadores por casa consolidados no Oracle; nulo fora do perfil oracle (o card some). */
  readonly indicadores = signal<IndicadoresResponse | null>(null);
  readonly consolidando = signal(false);
  readonly catalog = signal<CatalogItem[]>([]);
  readonly error = signal<string | null>(null);
  readonly notice = signal<string | null>(null);
  readonly saving = signal(false);
  readonly isAdmin = this.auth.isAdmin;

  /** Formulário do produto — todos os campos com [(ngModel)]. */
  form: CatalogItem = this.emptyForm();
  editing = false;
  riskFilter = '';

  readonly riskTags = [
    'fall_bathroom', 'fall_general', 'night_trips', 'mobility', 'cognition', 'environment',
    'dexterity', 'daily_living', 'emergency', 'home_security', 'caregiver_monitoring',
    'accessibility_voice', 'hydration', 'medication_adherence',
  ];

  readonly riskTagLabels = RISK_TAG_LABELS;

  ngOnInit(): void {
    this.loadCatalog();
    if (this.isAdmin()) {
      // A Operação não espera F5: os indicadores se renovam a cada 10s. Num tick com erro o
      // último valor fica na tela — o banner só aparece se nunca houve KPI carregado.
      interval(10_000)
        .pipe(
          startWith(0),
          switchMap(() =>
            forkJoin({
              kpis: this.api.kpis(),
              // O card de indicadores é acessório: se a rota falhar, os KPIs continuam chegando.
              indicadores: this.api.indicadores().pipe(catchError(() => of(null))),
            }).pipe(
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
        .subscribe(({ kpis, indicadores }) => {
          this.kpis.set(kpis);
          this.indicadores.set(indicadores?.engine === 'oracle' ? indicadores : null);
        });
    }
  }

  /** Roda a rotina diária do banco agora, em vez de esperar o agendamento. */
  consolidar(): void {
    this.consolidando.set(true);
    this.error.set(null);
    this.api
      .consolidarIndicadores()
      .pipe(switchMap((res) => this.api.indicadores().pipe(switchMap((ind) => of({ res, ind })))))
      .subscribe({
        next: ({ res, ind }) => {
          this.consolidando.set(false);
          this.indicadores.set(ind.engine === 'oracle' ? ind : null);
          this.flash(
            res.casasProcessadas === 1
              ? '1 casa consolidada pelo banco.'
              : `${res.casasProcessadas} casas consolidadas pelo banco.`,
          );
        },
        error: (err) => {
          this.consolidando.set(false);
          this.error.set(errorMessage(err));
        },
      });
  }

  readonly pct = percentualOuSemDados;
  readonly variacao = variacaoComSinal;
  readonly diaMes = diaMes;

  loadCatalog(): void {
    this.api.catalog(this.riskFilter || undefined).subscribe({
      next: (items) => this.catalog.set(items),
      error: (err) => this.error.set(errorMessage(err)),
    });
  }

  riskLabel(tag: string | null): string {
    return riskTagLabel(tag);
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
      // Item novo nasce sem parceiro: quem cadastra escolhe depois quem vende.
      partner: null,
      productUrl: null,
    };
  }

  private flash(message: string): void {
    this.notice.set(message);
    setTimeout(() => this.notice.set(null), 4000);
  }
}
