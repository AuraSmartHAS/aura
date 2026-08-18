import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { CatalogItem, Home, Kpis, Order, Recommendation, Score, Signal, TokenResponse } from './models';

/** Todas as chamadas ao backend Spring Boot passam por aqui. */
@Injectable({ providedIn: 'root' })
export class ApiService {
  /** Trocar por variável de ambiente ao publicar; localhost é o cenário da demo. */
  readonly baseUrl = 'http://localhost:8080/api/v1';

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

  orders(homeId: string): Observable<Order[]> {
    return this.http.get<Order[]>(`${this.baseUrl}/homes/${homeId}/orders`);
  }

  advance(orderId: string): Observable<{ stage: string; slaBreached: boolean }> {
    return this.http.post<{ stage: string; slaBreached: boolean }>(
      `${this.baseUrl}/orders/${orderId}/advance`,
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
}
