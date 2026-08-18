import { CommonModule } from '@angular/common';
import { Component, OnInit, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Observable } from 'rxjs';
import { ApiService } from '../../core/api.service';
import { errorMessage } from '../../core/error-message';
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
    slippery_floor: false,
    night_light: false,
    gas_detector: false,
    air_purifier: false,
  };

  readonly checklistLabels: Record<string, string> = {
    grab_bar_bathroom: 'Barra de apoio no banheiro',
    slippery_floor: 'Piso escorregadio',
    night_light: 'Iluminação noturna',
    gas_detector: 'Detector de gás/fumaça',
    air_purifier: 'Purificador de ar',
  };

  readonly stages = ['approved', 'sourcing', 'in_route', 'delivered', 'installed'];

  readonly stageLabels: Record<string, string> = {
    approved: 'Aprovado',
    sourcing: 'Separando',
    in_route: 'Em rota',
    delivered: 'Entregue',
    installed: 'Instalado',
    returned: 'Devolvido',
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
