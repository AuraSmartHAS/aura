import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { ComponentFixture, TestBed, fakeAsync, tick } from '@angular/core/testing';
import { environment } from '../../../environments/environment';
import { OrderDeliveryComponent } from './order-delivery';

const DETAIL = {
  orderId: 'o1',
  stage: 'in_route',
  sku: 'LM-ANTIDERRAP',
  productName: 'Piso Antiderrapante p/ Box (m²)',
  sla: { dueAt: null, breached: false, deliveredAt: null, installedAt: null },
  delivery: {
    nodeName: 'Loja Marginal',
    eta: '2026-09-01T17:30:00Z',
    distanceM: 2038,
    status: 'in_route',
    durationS: 294,
    progressPct: 60,
    currentPosition: [-46.6462, -23.5527] as [number, number],
    route: {
      type: 'LineString',
      coordinates: [
        [-46.64, -23.55],
        [-46.6462, -23.5527],
        [-46.656, -23.561],
      ] as [number, number][],
    },
  },
  createdAt: '2026-09-01T03:00:00Z',
};

describe('OrderDeliveryComponent', () => {
  let fixture: ComponentFixture<OrderDeliveryComponent>;
  let http: HttpTestingController;
  const url = `${environment.apiBaseUrl}/orders/o1`;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [OrderDeliveryComponent],
      providers: [provideHttpClient(), provideHttpClientTesting()],
    });
    http = TestBed.inject(HttpTestingController);
    fixture = TestBed.createComponent(OrderDeliveryComponent);
    fixture.componentRef.setInput('orderId', 'o1');
    fixture.componentRef.setInput('houseLabel', 'Maria S.');
  });

  afterEach(() => http.verify());

  it('busca o detalhe na abertura e de novo a cada 10 segundos', fakeAsync(() => {
    fixture.detectChanges();
    tick(0);
    http.expectOne(url).flush(DETAIL);
    fixture.detectChanges();

    const el: HTMLElement = fixture.nativeElement;
    expect(el.querySelector('svg')).not.toBeNull();
    expect(el.textContent).toContain('Saindo de: Loja Marginal');
    expect(el.textContent).toContain('2,0 km');
    expect(el.textContent).toContain('chega às');

    tick(10_000);
    http.expectOne(url).flush(DETAIL);
    fixture.destroy();
  }));

  it('erro num tick mantém o último quadro desenhado e o poll segue vivo', fakeAsync(() => {
    fixture.detectChanges();
    tick(0);
    http.expectOne(url).flush(DETAIL);
    fixture.detectChanges();

    tick(10_000);
    http.expectOne(url).flush(null, { status: 500, statusText: 'boom' });
    fixture.detectChanges();

    // o mapa não some nem vira banner de erro
    expect((fixture.nativeElement as HTMLElement).querySelector('svg')).not.toBeNull();

    tick(10_000);
    http.expectOne(url).flush(DETAIL);
    fixture.destroy();
  }));

  it('destruir o componente cancela o poll — nenhuma requisição órfã', fakeAsync(() => {
    fixture.detectChanges();
    tick(0);
    http.expectOne(url).flush(DETAIL);

    fixture.destroy();
    tick(30_000);
    http.expectNone(url);
  }));
});
