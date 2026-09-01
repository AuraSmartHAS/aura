import { CommonModule } from '@angular/common';
import { Component, DestroyRef, Input, OnInit, computed, inject, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { EMPTY, catchError, switchMap, timer } from 'rxjs';
import { ApiService } from '../../core/api.service';
import { OrderDetail } from '../../core/models';
import { projectRoute, toPath } from './route-geometry';

/**
 * Última milha do pedido: rota do nó logístico até a casa com o ponto do entregador andando.
 * O componente é dono do próprio poll (10 s) e a posição vem SEMPRE do servidor — a tela nunca
 * inventa onde o veículo está. Erro num tick mantém o último quadro desenhado.
 */
@Component({
  selector: 'app-order-delivery',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './order-delivery.html',
})
export class OrderDeliveryComponent implements OnInit {
  private readonly api = inject(ApiService);
  private readonly destroyRef = inject(DestroyRef);

  @Input({ required: true }) orderId!: string;
  @Input() houseLabel = 'Casa';

  readonly detail = signal<OrderDetail | null>(null);

  /** Geometria pronta pro template; nulo sem rota — a legenda sobrevive sozinha. */
  readonly view = computed(() => {
    const d = this.detail();
    const coordinates = d?.delivery.route?.coordinates;
    if (!d || !coordinates || coordinates.length < 2) {
      return null;
    }
    const { points, project } = projectRoute(coordinates, 640, 260, 40);
    const start = points[0];
    const end = points[points.length - 1];
    return {
      path: toPath(points),
      start,
      end,
      startLabel: this.labelFor(start),
      endLabel: this.labelFor(end),
      courier: d.delivery.currentPosition ? project(d.delivery.currentPosition) : null,
    };
  });

  ngOnInit(): void {
    timer(0, 10_000)
      .pipe(
        switchMap(() => this.api.orderDetail(this.orderId).pipe(catchError(() => EMPTY))),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe((d) => this.detail.set(d));
  }

  translate([x, y]: [number, number]): string {
    return `translate(${x} ${y})`;
  }

  km(distanceM: number): string {
    return (distanceM / 1000).toFixed(1).replace('.', ',');
  }

  /** Rótulo acima do ponto, grampeado pra não sair do quadro. */
  private labelFor([x, y]: [number, number]): [number, number] {
    return [Math.min(Math.max(x, 60), 580), Math.max(y - 16, 16)];
  }
}
