import { Platform } from 'react-native';

/**
 * Mesma API REST (Spring Boot) consumida pelo app Flutter e pelo painel Angular.
 * Em device físico troque pelo IP da máquina — localhost lá é o próprio aparelho.
 */
const HOST = Platform.OS === 'android' ? '10.0.2.2' : 'localhost';
export const BASE_URL = `http://${HOST}:8080/api/v1`;

let token: string | null = null;

export function setToken(value: string | null): void {
  token = value;
}

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const response = await fetch(`${BASE_URL}${path}`, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(init.headers ?? {}),
    },
  });

  const text = await response.text();
  const body = text ? JSON.parse(text) : null;

  if (!response.ok) {
    throw new Error(body?.error?.message ?? 'Falha na comunicação com o servidor.');
  }
  return body as T;
}

export type Level = 'low' | 'medium' | 'high';

export interface Home {
  id: string;
  label: string | null;
  patientName: string;
  address: string | null;
  safetyChecklist: Record<string, boolean>;
}

export interface Score {
  scoreId: string;
  dimension: string;
  level: Level;
  score: number;
  factors: string[];
  weights: number[];
  explanation: string;
}

export interface Recommendation {
  recommendationId: string;
  sku: string;
  productName: string;
  reason: string;
  status: string;
  factors: string[];
  weights: number[];
}

export interface Order {
  id: string;
  stage: string;
  productName: string;
  slaBreached: boolean;
}

export const api = {
  login: (email: string, password: string) =>
    request<{ token: string; role: string }>('/auth/login', {
      method: 'POST',
      body: JSON.stringify({ email, password }),
    }),

  homes: () => request<Home[]>('/homes'),

  latestScores: (homeId: string) => request<Score[]>(`/homes/${homeId}/scores/latest`),

  recompute: (homeId: string) =>
    request<Score>('/scores/recompute', { method: 'POST', body: JSON.stringify({ homeId }) }),

  registerSignal: (homeId: string, event: string) =>
    request<{ signalId: string }>('/signals', {
      method: 'POST',
      body: JSON.stringify({ homeId, type: 'mobility', source: 'self_report', value: { event } }),
    }),

  recommendations: (homeId: string) => request<Recommendation[]>(`/homes/${homeId}/recommendations`),

  recommend: (homeId: string, scoreId: string) =>
    request<Recommendation>('/recommendations', {
      method: 'POST',
      body: JSON.stringify({ homeId, scoreId }),
    }),

  approve: (recommendationId: string) =>
    request<{ orderId: string; stage: string }>(`/recommendations/${recommendationId}/approve`, {
      method: 'POST',
    }),

  orders: (homeId: string) => request<Order[]>(`/homes/${homeId}/orders`),

  advance: (orderId: string) =>
    request<{ stage: string; slaBreached: boolean }>(`/orders/${orderId}/advance`, { method: 'POST' }),
};
