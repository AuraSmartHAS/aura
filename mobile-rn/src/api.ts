import { Platform } from 'react-native';

/**
 * Mesma API REST (Spring Boot) consumida pelo app Flutter e pelo painel Angular.
 * Em device físico troque pelo IP da máquina — localhost lá é o próprio aparelho.
 */
const HOST = Platform.OS === 'android' ? '10.0.2.2' : 'localhost';

/** Em device físico, defina EXPO_PUBLIC_API_URL com o IP da máquina antes de iniciar o Expo. */
export const BASE_URL = process.env.EXPO_PUBLIC_API_URL ?? `http://${HOST}:8080/api/v1`;

let token: string | null = null;
let role: string | null = null;

export function setToken(value: string | null): void {
  token = value;
}

/** Papel devolvido pelo login (`admin`, `cuidadora`, `paciente`). */
export function setRole(value: string | null): void {
  role = value;
}

/**
 * Só a Operação move a cadeia logística: o backend responde 403 para qualquer outro papel
 * em `/orders/{id}/advance`. A tela esconde o botão em vez de oferecer uma ação que sempre falha.
 */
export function isAdmin(): boolean {
  return role === 'admin';
}

/** Há sessão aberta? É o que decide se o toque num aviso navega já ou espera o login. */
export function hasSession(): boolean {
  return token !== null;
}

/** A paciente não recebe a tela de quem cuida: o aviso tocado era endereçado a outra pessoa. */
export function isPatient(): boolean {
  return role === 'paciente';
}

/** Erro da API com o status HTTP: a tela distingue "sessão expirou" de "sem conexão". */
export class ApiError extends Error {
  constructor(
    message: string,
    readonly status: number,
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

export const SESSION_EXPIRED_MESSAGE = 'Sua sessão expirou. Entre novamente.';

/** 401 com sessão aberta: o token venceu ou foi revogado (não é senha errada nem rede). */
export function isSessionExpired(error: unknown): boolean {
  return error instanceof ApiError && error.status === 401 && error.message === SESSION_EXPIRED_MESSAGE;
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
  // Corpo que não é JSON (uma página de erro de proxy, por exemplo) não pode virar um
  // "Unexpected token <" na tela da cuidadora.
  let body: { error?: { message?: string } } | null = null;
  if (text) {
    try {
      body = JSON.parse(text);
    } catch {
      body = null;
    }
  }

  if (response.ok && text && body === null) {
    // 200 com HTML (proxy, portal cativo): não é a resposta da API, e o `null` quebraria a tela com
    // "Cannot read properties of null".
    throw new ApiError('Resposta inesperada do servidor.', response.status);
  }

  if (!response.ok) {
    // Com sessão aberta, 401 é "sua sessão expirou". Sem sessão (login), é senha errada: a mensagem
    // do servidor vale.
    if (response.status === 401 && token && !path.startsWith('/auth/')) throw new ApiError(SESSION_EXPIRED_MESSAGE, 401);
    throw new ApiError(body?.error?.message ?? 'Falha na comunicação com o servidor.', response.status);
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
  /** Rótulos em português dos fatores, na mesma ordem de `factors`. Vêm da API
   *  (a política de risco vive em YAML versionado) — a tela nunca traduz código. */
  factorLabels?: string[];
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
  /** Rótulos em português dos fatores, na mesma ordem de `factors`. */
  factorLabels?: string[];
  weights: number[];
  /** Pedido a caminho deste item: enquanto existir, o servidor não recomenda nem aprova outro igual. */
  orderInProgress?: { orderId: string; stage: string } | null;
}

export interface Order {
  id: string;
  stage: string;
  productName: string;
  slaBreached: boolean;
}

/** Um sinal da casa (`GET /homes/{id}/signals`): matéria-prima da linha do tempo. */
export interface CareSignal {
  id: string;
  /** `adherence`, `mobility`, `sleep`, `vitals`… */
  type: string;
  /** `voice`, `self_report`, `usage` ou `wearable`. */
  source: string;
  value: Record<string, unknown>;
  /** ISO-8601 em UTC; a tela converte para a hora local. */
  capturedAt: string;
}

export interface MedicationRecord {
  id: string;
  homeId: string;
  name: string;
  dosage: string | null;
  /** Horários `HH:mm`; vazio = "quando necessário". */
  schedule: string[];
  notes: string | null;
  active: boolean;
  stockDoses: number | null;
}

/** SOS em aberto da casa; também é o corpo do "estou indo". */
export interface ActiveEmergency {
  emergencyId: string;
  /** `waiting_cancel`, `dispatched`, `escalated` ou `acknowledged`. */
  state: string;
  createdAt?: string;
  acknowledgedByName?: string | null;
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

  /**
   * Sinais da casa desde `since` (o servidor recebe em UTC). Sem recorte de data, "os N últimos"
   * misturam leituras do relógio e empurram a dose do dia para fora da página — e a tela passaria a
   * afirmar "atrasada" para uma dose tomada.
   */
  signals: (homeId: string, since?: Date, limit = 200, type?: string) =>
    request<CareSignal[]>(
      `/homes/${homeId}/signals?limit=${limit}${type ? `&type=${type}` : ''}${since ? `&from=${encodeURIComponent(since.toISOString())}` : ''}`,
    ),

  /** Por nome, como o app Flutter lista: as duas telas mostram os remédios na mesma ordem. */
  medications: async (homeId: string) =>
    (await request<MedicationRecord[]>(`/homes/${homeId}/medications`)).sort((a, b) =>
      a.name.localeCompare(b.name, 'pt-BR', { sensitivity: 'base' }),
    ),

  /** Cadastra o medicamento; o servidor devolve o registro salvo (sem refazer a lista). */
  createMedication: (homeId: string, body: Record<string, unknown>) =>
    request<MedicationRecord>(`/homes/${homeId}/medications`, { method: 'POST', body: JSON.stringify(body) }),

  updateMedication: (medicationId: string, body: Record<string, unknown>) =>
    request<MedicationRecord>(`/medications/${medicationId}`, { method: 'PUT', body: JSON.stringify(body) }),

  deleteMedication: (medicationId: string) =>
    request<{ deleted: boolean }>(`/medications/${medicationId}`, { method: 'DELETE' }),

  /** SOS em aberto; `null` no 204 (nada acontecendo). */
  activeEmergency: (homeId: string) =>
    request<ActiveEmergency | null>(`/homes/${homeId}/emergencies/active`),

  /** Estado do aviso (rota aberta e magra): como um SOS que deixou de estar em aberto terminou. */
  emergencyOutcome: (emergencyId: string) => request<ActiveEmergency>(`/emergencies/${emergencyId}`),

  /** "Estou indo": fecha o loop e para o escalonamento. */
  acknowledgeEmergency: (emergencyId: string) =>
    request<ActiveEmergency>(`/emergencies/${emergencyId}/ack`, { method: 'POST' }),

  /** Registra o token FCM deste aparelho: um aparelho é de uma pessoa só (o servidor o tira de outra). */
  registerPushToken: (fcmToken: string) =>
    request<{ ok: boolean }>('/notifications/register-token', {
      method: 'POST',
      body: JSON.stringify({ fcmToken }),
    }),

  /**
   * Logout: o aparelho deixa de receber os avisos de quem saiu. Com o token, o servidor só apaga se
   * ele ainda for o registrado — o logout atrasado de um aparelho antigo não desliga o atual.
   */
  unregisterPushToken: (fcmToken: string | null) =>
    request<{ ok: boolean }>('/notifications/register-token', {
      method: 'DELETE',
      ...(fcmToken ? { body: JSON.stringify({ fcmToken }) } : {}),
    }),
};
