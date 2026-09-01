/** Espelha o contrato do backend Spring Boot (/api/v1). */

export type Role = 'paciente' | 'cuidadora' | 'profissional' | 'admin';
export type RiskLevel = 'low' | 'medium' | 'high';
export type OrderStage = 'approved' | 'sourcing' | 'in_route' | 'delivered' | 'installed' | 'returned';

export interface TokenResponse {
  token: string;
  role: Role;
  refreshToken: string;
}

export interface Home {
  id: string;
  label: string | null;
  patientName: string;
  birthDate: string | null;
  cep: string | null;
  address: string | null;
  lat: number | null;
  lng: number | null;
  safetyChecklist: Record<string, boolean>;
}

export interface Score {
  scoreId: string;
  dimension: string;
  level: RiskLevel;
  score: number;
  factors: string[];
  weights: number[];
  explanation: string;
  configVersion: string;
}

export interface Recommendation {
  recommendationId: string;
  sku: string;
  productName: string;
  reason: string;
  status: 'recommended' | 'approved' | 'rejected';
  factors: string[];
  weights: number[];
  /** Rótulos prontos em português — a tela não retraduz o que o servidor já explicou. */
  factorLabels: string[];
  /** Nulos quando o SKU saiu do catálogo: preço ausente nunca vira "R$ null". */
  price: number | null;
  installable: boolean | null;
  installationIncluded: boolean | null;
  installationPrice: number | null;
  normRef: string | null;
}

export interface Order {
  id: string;
  stage: OrderStage;
  sku: string;
  productName: string;
  slaDueAt: string | null;
  slaBreached: boolean;
  createdAt: string;
  recommendationId: string;
}

export interface CatalogItem {
  sku: string;
  name: string;
  category: string;
  price: number;
  installable: boolean;
  normRef: string | null;
  riskTag: string | null;
  stockNearby: number;
}

export interface Kpis {
  otif: number;
  fillRate: number;
  leadTimeHours: number;
  openOrders: number;
  slaBreaches: number;
  homes: number;
  signals: number;
  highRiskScores: number;
  uptime: string;
  byStage: { stage: string; count: number }[];
}

export interface Signal {
  id: string;
  type: string;
  source: string;
  value: Record<string, unknown>;
  capturedAt: string;
}
