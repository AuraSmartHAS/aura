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
      partner: null, productUrl: null,
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

  it('check de reposição projeta por POST com corpo vazio', () => {
    api.replenishmentCheck('casa-1').subscribe();

    const req = http.expectOne(`${api.baseUrl}/homes/casa-1/replenishment/check`);
    expect(req.request.method).toBe('POST');
    expect(req.request.body).toEqual({});
    req.flush([]);
  });

  it('aprovar recomendação bate na rota de aprovação (única porta do pedido)', () => {
    api.approve('rec-1').subscribe();
    const req = http.expectOne(`${api.baseUrl}/recommendations/rec-1/approve`);
    expect(req.request.method).toBe('POST');
    req.flush({ orderId: 'o1', stage: 'approved' });
  });

  it('recusar recomendação bate na rota de recusa, com corpo vazio', () => {
    api.reject('rec-1').subscribe();
    const req = http.expectOne(`${api.baseUrl}/recommendations/rec-1/reject`);
    expect(req.request.method).toBe('POST');
    expect(req.request.body).toEqual({});
    req.flush({ status: 'rejected' });
  });

  it('avisos da casa e processamento sob demanda batem nas rotas da procedure', () => {
    api.alertas('casa-1').subscribe();
    const lista = http.expectOne(`${api.baseUrl}/homes/casa-1/alertas`);
    expect(lista.request.method).toBe('GET');
    lista.flush({ engine: 'oracle', alertas: [] });

    api.processarAlertas('casa-1').subscribe();
    const processar = http.expectOne(`${api.baseUrl}/homes/casa-1/alertas/processar`);
    expect(processar.request.method).toBe('POST');
    expect(processar.request.body).toEqual({});
    processar.flush({ engine: 'oracle', novos: 1 });

    api.marcarAlertaVisto('a1').subscribe();
    const visto = http.expectOne(`${api.baseUrl}/alertas/a1/visto`);
    expect(visto.request.method).toBe('POST');
    visto.flush({ id: 'a1', status: 'visto' });
  });

  it('relatório de consumo só manda o período quando informado', () => {
    api.relatorioConsumo('casa-1').subscribe();
    const semPeriodo = http.expectOne((r) => r.url === `${api.baseUrl}/homes/casa-1/relatorio-consumo`);
    expect(semPeriodo.request.params.keys()).toEqual([]);
    semPeriodo.flush({ engine: 'oracle', de: '', ate: '', totalDoses: 0, demandaEncaminhadaReais: 0, itens: [] });

    api.relatorioConsumo('casa-1', '2026-09-27', '2026-10-04').subscribe();
    const comPeriodo = http.expectOne((r) => r.url === `${api.baseUrl}/homes/casa-1/relatorio-consumo`);
    expect(comPeriodo.request.params.get('de')).toBe('2026-09-27');
    expect(comPeriodo.request.params.get('ate')).toBe('2026-10-04');
    comPeriodo.flush({ engine: 'oracle', de: '', ate: '', totalDoses: 0, demandaEncaminhadaReais: 0, itens: [] });
  });

  it('indicadores da Operação leem e consolidam pelas rotas de admin', () => {
    api.indicadores().subscribe();
    const ler = http.expectOne(`${api.baseUrl}/ops/indicadores`);
    expect(ler.request.method).toBe('GET');
    ler.flush({ engine: 'oracle', dataRef: '2026-10-04', casas: [] });

    api.consolidarIndicadores().subscribe();
    const consolidar = http.expectOne(`${api.baseUrl}/ops/indicadores/consolidar`);
    expect(consolidar.request.method).toBe('POST');
    consolidar.flush({ engine: 'oracle', casasProcessadas: 2 });
  });
});
