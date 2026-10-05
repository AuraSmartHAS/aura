/** Espelha o contrato do backend Spring Boot (/api/v1). */

export type Role = 'paciente' | 'cuidadora' | 'profissional' | 'admin';
export type RiskLevel = 'low' | 'medium' | 'high';

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
  /** Fornecedor que vende o item. O Aura não vende: entrega a demanda a quem vende. */
  partner: string | null;
  /** Endereço do item no site do parceiro. Nulo = sem link, e a tela não promete um. */
  productUrl: string | null;
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
  partner: string | null;
  productUrl: string | null;
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

/** Projeção da reposição por consumo (POST /homes/{id}/replenishment/check) — a conta viaja aberta. */
export interface ReplenishmentProjection {
  medicationId: string;
  medicationName: string;
  stockDoses: number | null;
  avgDosesPerDay: number | null;
  daysOfSupply: number | null;
  leadTimeHours: number;
  safetyStockDays: number;
  thresholdDays: number;
  suggested: boolean;
  recommendationId: string | null;
  reason: string | null;
}

export interface Signal {
  id: string;
  type: string;
  source: string;
  value: Record<string, unknown>;
  capturedAt: string;
}
