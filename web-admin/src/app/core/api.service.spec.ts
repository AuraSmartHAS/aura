import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { ApiService } from './api.service';
import { environment } from '../../environments/environment';

describe('ApiService', () => {
  let api: ApiService;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [ApiService, provideHttpClient(), provideHttpClientTesting()],
    });
    api = TestBed.inject(ApiService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  it('usa a base configurada no environment', () => {
    expect(api.baseUrl).toBe(environment.apiBaseUrl);
  });

  it('login envia e-mail e senha no corpo', () => {
    api.login('ana@aura.com', 'aura1234').subscribe();

    const req = http.expectOne(`${api.baseUrl}/auth/login`);
    expect(req.request.method).toBe('POST');
    expect(req.request.body).toEqual({ email: 'ana@aura.com', password: 'aura1234' });
    req.flush({ token: 't', role: 'cuidadora', refreshToken: 'r' });
  });

  it('recompute manda a casa e a dimensão opcional', () => {
    api.recompute('casa-1', 'mobility').subscribe();

    const req = http.expectOne(`${api.baseUrl}/scores/recompute`);
    expect(req.request.body).toEqual({ homeId: 'casa-1', dimension: 'mobility' });
    req.flush({ scoreId: 's1', dimension: 'mobility', level: 'high', score: 0.9, factors: [], weights: [] });
  });

  it('catálogo só manda riskTag quando há filtro', () => {
    api.catalog().subscribe();
    const semFiltro = http.expectOne((r) => r.url === `${api.baseUrl}/catalog`);
    expect(semFiltro.request.params.has('riskTag')).toBeFalse();
    semFiltro.flush([]);

    api.catalog('fall_bathroom').subscribe();
    const comFiltro = http.expectOne((r) => r.url === `${api.baseUrl}/catalog`);
    expect(comFiltro.request.params.get('riskTag')).toBe('fall_bathroom');
    comFiltro.flush([]);
  });

  it('salvar produto usa POST quando é novo e PUT quando existe', () => {
    const corpo = {
      name: 'Barra 90cm', category: 'Barra de apoio', price: 99.9,
      installable: true, normRef: 'NBR 9050', riskTag: 'fall_bathroom', stockNearby: 3,
    };

    api.saveProduct('LM-NOVO', corpo, true).subscribe();
    const criado = http.expectOne(`${api.baseUrl}/catalog/LM-NOVO`);
    expect(criado.request.method).toBe('POST');
    criado.flush({ sku: 'LM-NOVO', ...corpo });

    api.saveProduct('LM-NOVO', corpo, false).subscribe();
    const atualizado = http.expectOne(`${api.baseUrl}/catalog/LM-NOVO`);
    expect(atualizado.request.method).toBe('PUT');
    atualizado.flush({ sku: 'LM-NOVO', ...corpo });
  });

  it('aprovar recomendação bate na rota de aprovação (única porta do pedido)', () => {
    api.approve('rec-1').subscribe();
    const req = http.expectOne(`${api.baseUrl}/recommendations/rec-1/approve`);
    expect(req.request.method).toBe('POST');
    req.flush({ orderId: 'o1', stage: 'approved' });
  });
});
