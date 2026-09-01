import { CommonModule } from '@angular/common';
import { Component, OnInit, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Observable } from 'rxjs';
import { ApiService } from '../../core/api.service';
import { errorMessage } from '../../core/error-message';
import { RECOMMENDATION_STATUS_LABELS, STAGE_LABELS } from '../../core/labels';
import { Home, Order, Recommendation, Score, Signal } from '../../core/models';

/** Acompanhamento de uma casa: risco explicado → recomendação → aprovação → entrega. */
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
  readonly orders = signal<Order[]>([]);
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

  readonly checklistLabels: Record<string, string> = {
    grab_bar_bathroom: 'Barra de apoio no banheiro',
    anti_slip_floor: 'Piso anti-derrapante',
    night_light: 'Iluminação noturna',
    gas_detector: 'Detector de gás/fumaça',
    air_purifier: 'Purificador de ar',
  };

  readonly stages = ['approved', 'sourcing', 'in_route', 'delivered', 'installed'];

  readonly stageLabels = STAGE_LABELS;
  readonly recStatusLabels = RECOMMENDATION_STATUS_LABELS;

  /** Dimensão observada do sinal (ver SignalType no backend). */
  readonly signalTypeLabels: Record<string, string> = {
    mobility: 'Mobilidade',
    sleep: 'Sono',
    cognition: 'Cognição',
    mood: 'Humor',
    environment: 'Ambiente',
    adherence: 'Adesão ao tratamento',
    vitals: 'Sinais vitais',
  };

  /** Origem do sinal (ver SignalSource no backend). */
  readonly signalSourceLabels: Record<string, string> = {
    voice: 'Assistente de voz',
    self_report: 'Relato da pessoa ou cuidadora',
    usage: 'Uso do aplicativo',
    wearable: 'Dispositivo vestível',
  };

  /** Vocabulário de eventos conhecidos (ver scoring-weights.yml no backend). */
  readonly signalEventLabels: Record<string, string> = {
    near_fall: 'Queda ou quase-queda registrada',
    dizziness: 'Tontura relatada',
    night_trip: 'Idas noturnas ao banheiro',
    confusion: 'Confusão ou repetição na fala registrada',
    poor_air: 'Qualidade do ar ruim relatada',
  };

  /** Local onde o evento ocorreu, quando informado. */
  readonly signalPlaceLabels: Record<string, string> = {
    bathroom: 'banheiro',
  };

  /** Nomes de fator do escore explicável (ver scoring-weights.yml no backend). */
  readonly scoreFactorLabels: Record<string, string> = {
    near_fall_reported: 'quase-queda relatada',
    no_grab_bar: 'ausência de barra de apoio',
    anti_slip_floor: 'ausência de piso anti-derrapante',
    dizziness_bath: 'tontura ao banho',
    night_trips_reported: 'idas noturnas frequentes',
    poor_night_lighting: 'iluminação noturna insuficiente',
    confusion_reported: 'confusão/repetição na fala',
    no_gas_detector: 'sem detector de gás/fumaça',
    poor_air_reported: 'qualidade do ar ruim relatada',
    no_air_purifier: 'sem purificador de ar',
  };

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
    this.api.recommendations(homeId).subscribe({ next: (r) => this.recommendations.set(r) });
    this.api.orders(homeId).subscribe({ next: (o) => this.orders.set(o) });
    this.api.signals(homeId, 8).subscribe({ next: (s) => this.signals.set(s) });
  }

  saveChecklist(): void {
    const home = this.selected();
    if (!home) {
      return;
    }
    this.run('checklist', this.api.updateChecklist(home.id, this.checklist), () =>
      this.flash('Checklist salvo. Recalcule o escore para ver o efeito no risco.'),
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
      this.flash('Escore recalculado com os fatores atuais.');
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
      this.flash('Aprovado. O pedido entrou na cadeia logística.');
      this.refresh(home.id);
    });
  }

  advance(order: Order): void {
    const home = this.selected();
    if (!home) {
      return;
    }
    this.run('advance-' + order.id, this.api.advance(order.id), (res) => {
      this.flash(`Pedido avançou para ${this.stageLabels[res.stage] ?? res.stage}.`);
      this.refresh(home.id);
    });
  }

  stageIndex(stage: string): number {
    return this.stages.indexOf(stage);
  }

  /** Instalado e devolvido são finais: sem próximo estágio, sem botão que devolva por engano. */
  canAdvance(order: Order): boolean {
    return order.stage !== 'installed' && order.stage !== 'returned';
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
