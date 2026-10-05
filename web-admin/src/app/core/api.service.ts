import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';
import {
  AlertasResponse,
  CatalogItem,
  Home,
  IndicadoresResponse,
  Kpis,
  Recommendation,
  RelatorioConsumo,
  ReplenishmentProjection,
  Score,
  Signal,
  TokenResponse,
} from './models';

/** Todas as chamadas ao backend Spring Boot passam por aqui. */
@Injectable({ providedIn: 'root' })
export class ApiService {
  readonly baseUrl = environment.apiBaseUrl;

  private readonly http = inject(HttpClient);

  login(email: string, password: string): Observable<TokenResponse> {
    return this.http.post<TokenResponse>(`${this.baseUrl}/auth/login`, { email, password });
  }

  homes(): Observable<Home[]> {
    return this.http.get<Home[]>(`${this.baseUrl}/homes`);
  }

  home(homeId: string): Observable<Home> {
    return this.http.get<Home>(`${this.baseUrl}/homes/${homeId}`);
  }

  updateChecklist(homeId: string, items: Record<string, boolean>): Observable<{ safetyChecklist: Record<string, boolean> }> {
    return this.http.put<{ safetyChecklist: Record<string, boolean> }>(
      `${this.baseUrl}/homes/${homeId}/checklist`,
      { items },
    );
  }

  signals(homeId: string, limit = 10): Observable<Signal[]> {
    return this.http.get<Signal[]>(`${this.baseUrl}/homes/${homeId}/signals`, {
      params: new HttpParams().set('limit', limit),
    });
  }

  registerSignal(homeId: string, type: string, event: string): Observable<{ signalId: string }> {
    return this.http.post<{ signalId: string }>(`${this.baseUrl}/signals`, {
      homeId,
      type,
      source: 'self_report',
      value: { event },
    });
  }

  recompute(homeId: string, dimension?: string): Observable<Score> {
    return this.http.post<Score>(`${this.baseUrl}/scores/recompute`, { homeId, dimension });
  }

  latestScores(homeId: string): Observable<Score[]> {
    return this.http.get<Score[]>(`${this.baseUrl}/homes/${homeId}/scores/latest`);
  }

  recommend(homeId: string, scoreId: string): Observable<Recommendation> {
    return this.http.post<Recommendation>(`${this.baseUrl}/recommendations`, { homeId, scoreId });
  }

  recommendations(homeId: string): Observable<Recommendation[]> {
    return this.http.get<Recommendation[]>(`${this.baseUrl}/homes/${homeId}/recommendations`);
  }

  approve(recommendationId: string): Observable<{ orderId: string; stage: string }> {
    return this.http.post<{ orderId: string; stage: string }>(
      `${this.baseUrl}/recommendations/${recommendationId}/approve`,
      {},
    );
  }

  reject(recommendationId: string): Observable<{ status: string }> {
    return this.http.post<{ status: string }>(
      `${this.baseUrl}/recommendations/${recommendationId}/reject`,
      {},
    );
  }

  /** Projeta o estoque contra o consumo confirmado; a régua disparada materializa recomendação. */
  replenishmentCheck(homeId: string): Observable<ReplenishmentProjection[]> {
    return this.http.post<ReplenishmentProjection[]>(
      `${this.baseUrl}/homes/${homeId}/replenishment/check`,
      {},
    );
  }

  catalog(riskTag?: string): Observable<CatalogItem[]> {
    let params = new HttpParams();
    if (riskTag) {
      params = params.set('riskTag', riskTag);
    }
    return this.http.get<CatalogItem[]>(`${this.baseUrl}/catalog`, { params });
  }

  saveProduct(sku: string, body: Omit<CatalogItem, 'sku'>, isNew: boolean): Observable<CatalogItem> {
    const url = `${this.baseUrl}/catalog/${sku}`;
    return isNew ? this.http.post<CatalogItem>(url, body) : this.http.put<CatalogItem>(url, body);
  }

  deleteProduct(sku: string): Observable<{ deleted: boolean }> {
    return this.http.delete<{ deleted: boolean }>(`${this.baseUrl}/catalog/${sku}`);
  }

  kpis(): Observable<Kpis> {
    return this.http.get<Kpis>(`${this.baseUrl}/ops/kpis`);
  }


  // --- Inteligência no Oracle (Fase 6): cada rota abaixo chega a uma function/procedure PL/SQL. ---

  alertas(homeId: string): Observable<AlertasResponse> {
    return this.http.get<AlertasResponse>(`${this.baseUrl}/homes/${homeId}/alertas`);
  }

  /** Roda PRC_REGISTRAR_ALERTAS sob demanda; a mesma procedure já roda sozinha a cada leitura. */
  processarAlertas(homeId: string): Observable<{ engine: string; novos: number }> {
    return this.http.post<{ engine: string; novos: number }>(
      `${this.baseUrl}/homes/${homeId}/alertas/processar`,
      {},
    );
  }

  marcarAlertaVisto(alertaId: string): Observable<{ id: string; status: string }> {
    return this.http.post<{ id: string; status: string }>(`${this.baseUrl}/alertas/${alertaId}/visto`, {});
  }

  /** Período em datas locais (AAAA-MM-DD); sem período, o backend usa os últimos 7 dias. */
  relatorioConsumo(homeId: string, de?: string, ate?: string): Observable<RelatorioConsumo> {
    let params = new HttpParams();
    if (de) {
      params = params.set('de', de);
    }
    if (ate) {
      params = params.set('ate', ate);
    }
    return this.http.get<RelatorioConsumo>(`${this.baseUrl}/homes/${homeId}/relatorio-consumo`, { params });
  }

  indicadores(): Observable<IndicadoresResponse> {
    return this.http.get<IndicadoresResponse>(`${this.baseUrl}/ops/indicadores`);
  }

  consolidarIndicadores(): Observable<{ engine: string; casasProcessadas: number }> {
    return this.http.post<{ engine: string; casasProcessadas: number }>(
      `${this.baseUrl}/ops/indicadores/consolidar`,
      {},
    );
  }
}
