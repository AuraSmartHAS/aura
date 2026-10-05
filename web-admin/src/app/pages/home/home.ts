import { CommonModule } from '@angular/common';
import { Component, OnInit, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Observable } from 'rxjs';
import { ApiService } from '../../core/api.service';
import { errorMessage } from '../../core/error-message';
import {
  CHECKLIST_LABELS,
  DIMENSION_LABELS,
  RECOMMENDATION_STATUS_LABELS,
  RISK_LEVEL_LABELS,
  SCORE_FACTOR_LABELS,
  SIGNAL_EVENT_LABELS,
  SIGNAL_PLACE_LABELS,
  SIGNAL_SOURCE_LABELS,
  SIGNAL_TYPE_LABELS,
} from '../../core/labels';
import { Home, Recommendation, ReplenishmentProjection, Score, Signal } from '../../core/models';

/** Acompanhamento de uma casa: risco explicado → recomendação → aprovação → site do parceiro. */
@Component({
  selector: 'app-home',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './home.html',
})
export class HomePageComponent implements OnInit {
  private readonly api = inject(ApiService);

  readonly homes = signal<Home[]>([]);
  readonly selected = signal<Home | null>(null);
  readonly scores = signal<Score[]>([]);
  readonly recommendations = signal<Recommendation[]>([]);
  readonly replenishment = signal<ReplenishmentProjection[]>([]);
  readonly signals = signal<Signal[]>([]);

  readonly loading = signal(false);
  readonly busy = signal<string | null>(null);
  readonly error = signal<string | null>(null);
  readonly notice = signal<string | null>(null);

  /** Chaves do checklist ligadas por [(ngModel)] nos checkboxes. */
  checklist: Record<string, boolean> = {
    grab_bar_bathroom: false,
    anti_slip_floor: false,
    night_light: false,
    gas_detector: false,
    air_purifier: false,
  };

  readonly checklistLabels = CHECKLIST_LABELS;

  readonly recStatusLabels = RECOMMENDATION_STATUS_LABELS;
  readonly dimensionLabels = DIMENSION_LABELS;
  readonly levelLabels = RISK_LEVEL_LABELS;

  readonly signalTypeLabels = SIGNAL_TYPE_LABELS;
  readonly signalSourceLabels = SIGNAL_SOURCE_LABELS;
  readonly signalEventLabels = SIGNAL_EVENT_LABELS;
  readonly signalPlaceLabels = SIGNAL_PLACE_LABELS;
  readonly scoreFactorLabels = SCORE_FACTOR_LABELS;

  ngOnInit(): void {
    this.loading.set(true);
    this.api.homes().subscribe({
      next: (homes) => {
        this.homes.set(homes);
        this.loading.set(false);
        if (homes.length > 0) {
          this.select(homes[0]);
        }
      },
      error: (err) => {
        this.loading.set(false);
        this.error.set(errorMessage(err));
      },
    });
  }

  select(home: Home): void {
    this.selected.set(home);
    this.checklist = { ...this.checklist, ...(home.safetyChecklist ?? {}) };
    this.refresh(home.id);
  }

  onSelectHome(homeId: string): void {
    const home = this.homes().find((h) => h.id === homeId);
    if (home) {
      this.select(home);
    }
  }

  private refresh(homeId: string): void {
    this.api.latestScores(homeId).subscribe({ next: (s) => this.scores.set(s) });
    this.api.signals(homeId, 8).subscribe({ next: (s) => this.signals.set(s) });
    // o check pode materializar recomendação nova — as recomendações carregam depois dele
    this.api.replenishmentCheck(homeId).subscribe({
      next: (r) => {
        this.replenishment.set(r);
        this.loadRecommendations(homeId);
      },
      error: () => this.loadRecommendations(homeId),
    });
  }

  private loadRecommendations(homeId: string): void {
    this.api.recommendations(homeId).subscribe({ next: (r) => this.recommendations.set(r) });
  }

  /** Só as projeções em que a régua disparou — o card não existe sem motivo. */
  suggestedReplenishments(): ReplenishmentProjection[] {
    return this.replenishment().filter((p) => p.suggested);
  }

  /** A recomendação materializada pelo check, se ainda aguarda decisão humana. */
  replenishmentRec(p: ReplenishmentProjection): Recommendation | undefined {
    return this.recommendations().find(
      (r) => r.recommendationId === p.recommendationId && r.status === 'recommended',
    );
  }

  roundDays(days: number | null): number {
    return Math.round(days ?? 0);
  }

  saveChecklist(): void {
    const home = this.selected();
    if (!home) {
      return;
    }
    this.run('checklist', this.api.updateChecklist(home.id, this.checklist), () =>
      this.flash('Checklist salvo. Atualize as leituras para ver o efeito no risco.'),
    );
  }

  registerNearFall(): void {
    const home = this.selected();
    if (!home) {
      return;
    }
    this.run('signal', this.api.registerSignal(home.id, 'mobility', 'near_fall'), () => {
      this.flash('Quase-queda registrada no histórico da Maria.');
      this.refresh(home.id);
    });
  }

  recompute(): void {
    const home = this.selected();
    if (!home) {
      return;
    }
    this.run('score', this.api.recompute(home.id), () => {
      this.flash('Leituras atualizadas. O risco reflete o estado atual da casa.');
      this.refresh(home.id);
    });
  }

  recommend(score: Score): void {
    const home = this.selected();
    if (!home) {
      return;
    }
    this.run('rec', this.api.recommend(home.id, score.scoreId), () => {
      this.flash('Recomendação gerada — aguarda aprovação da cuidadora.');
      this.refresh(home.id);
    });
  }

  approve(rec: Recommendation): void {
    const home = this.selected();
    if (!home) {
      return;
    }
    this.run('approve-' + rec.recommendationId, this.api.approve(rec.recommendationId), () => {
      this.flash('Aprovado. A compra segue no site do parceiro.');
      this.refresh(home.id);
    });
  }

  reject(rec: Recommendation): void {
    const home = this.selected();
    if (!home) {
      return;
    }
    this.run('reject-' + rec.recommendationId, this.api.reject(rec.recommendationId), () => {
      this.flash('Recomendação recusada. Nenhum pedido foi criado.');
      this.refresh(home.id);
    });
  }

  describeSignalType(signal: Signal): string {
    return this.signalTypeLabels[signal.type] ?? this.humanize(signal.type);
  }

  describeSignalSource(signal: Signal): string {
    return this.signalSourceLabels[signal.source] ?? this.humanize(signal.source);
  }

  /** Traduz o `value` do sinal (JSON só faz sentido no código) para uma frase legível. */
  describeSignalContent(signal: Signal): string {
    const value = signal.value ?? {};
    const entries = Object.entries(value);

    if (typeof value['event'] === 'string') {
      const event = value['event'] as string;
      const description = this.signalEventLabels[event] ?? this.humanize(event);
      const place = typeof value['place'] === 'string' ? value['place'] : null;
      const placeLabel = place ? this.signalPlaceLabels[place] ?? this.humanize(place) : null;
      return placeLabel ? `${description} · Local: ${placeLabel}` : description;
    }

    if (typeof value['taken'] === 'boolean') {
      return value['taken'] ? 'Medicação/tratamento tomado' : 'Medicação/tratamento não tomado';
    }

    if (entries.length === 0) {
      return 'Sem detalhes adicionais.';
    }

    return entries
      .map(([key, val]) => `${this.humanize(key)}: ${this.humanize(String(val))}`)
      .join(' · ');
  }

  describeScoreFactor(factor: string): string {
    return this.scoreFactorLabels[factor] ?? this.humanize(factor);
  }

  /** Prefere os rótulos que o servidor mandou; sem eles, cai no dicionário local do escore. */
  recFactorLabels(rec: Recommendation): string[] {
    return rec.factorLabels?.length > 0
      ? rec.factorLabels
      : rec.factors.map((factor) => this.describeScoreFactor(factor));
  }

  /** Instalação só entra na conta quando o item é instalável e o serviço é cobrado à parte. */
  needsInstallation(rec: Recommendation): boolean {
    return rec.installable === true && !rec.installationIncluded && rec.installationPrice !== null;
  }

  /** O total que a cuidadora aprova — é este número que a fala da demo cita. */
  recTotal(rec: Recommendation): number {
    return (rec.price ?? 0) + (this.needsInstallation(rec) ? (rec.installationPrice ?? 0) : 0);
  }

  /** Fallback para códigos ainda não mapeados: "near_fall" -> "Near fall". */
  private humanize(raw: string): string {
    const spaced = raw.replace(/_/g, ' ');
    return spaced.charAt(0).toUpperCase() + spaced.slice(1);
  }

  levelClass(level: string): string {
    return `badge badge--${level}`;
  }

  percent(value: number): string {
    return `${Math.round(value * 100)}%`;
  }

  private run<T>(key: string, source: Observable<T>, done: (value: T) => void): void {
    this.busy.set(key);
    this.error.set(null);
    source.subscribe({
      next: (value) => {
        this.busy.set(null);
        done(value);
      },
      error: (err: unknown) => {
        this.busy.set(null);
        this.error.set(errorMessage(err));
      },
    });
  }

  private flash(message: string): void {
    this.notice.set(message);
    setTimeout(() => this.notice.set(null), 4000);
  }
}
