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

/** Pedido que já cobre o item: enquanto existir, o servidor não recomenda nem aprova outro igual. */
export interface OrderInProgress {
  orderId: string;
  stage: string;
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
  /** Pedido a caminho deste item; nulo quando ninguém o pediu ainda ou ele já foi instalado. */
  orderInProgress?: OrderInProgress | null;
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
  /** Reposição já pedida e ainda não entregue: a régua não sugere outra até o estoque subir. */
  orderInProgress?: OrderInProgress | null;
  /** "Deixar para depois": a sugestão fica calada até este instante (ISO) ou até a próxima entrega. */
  snoozedUntil?: string | null;
}

export interface Signal {
  id: string;
  type: string;
  source: string;
  value: Record<string, unknown>;
  capturedAt: string;
}

/**
 * Inteligência que roda dentro do Oracle (functions e procedures PL/SQL, Fase 6).
 * Fora do perfil oracle o backend responde engine "indisponivel" com listas vazias, e a tela
 * esconde os cards em vez de mostrar um zero que pareceria medição.
 */
export type Engine = 'oracle' | 'indisponivel';

/** Aviso gravado pela procedure PRC_REGISTRAR_ALERTAS a partir das regras ativas no banco. */
export interface Alerta {
  id: string;
  regra: string;
  severidade: 'info' | 'atencao' | 'alta';
  mensagem: string;
  status: 'aberto' | 'visto';
  criadoEm: string;
}

export interface AlertasResponse {
  engine: Engine;
  alertas: Alerta[];
}

/** Uma linha do relatório de consumo (PRC_RELATORIO_CONSUMO, cursor por medicação). */
export interface ItemConsumo {
  medicamento: string;
  dosesConfirmadas: number;
  dosesNegadas: number;
  dosesEsperadas: number;
  /** FN_TAXA_ADESAO: nulo quando não há dose esperada no período — "sem dados", nunca 0%. */
  adesaoPct: number | null;
  estoqueDoses: number | null;
}

export interface RelatorioConsumo {
  engine: Engine;
  de: string;
  ate: string;
  totalDoses: number | null;
  /** Soma das recomendações aprovadas a preço de referência do parceiro; o Aura não vende. */
  demandaEncaminhadaReais: number | null;
  itens: ItemConsumo[];
}

/** Indicadores do dia por casa, consolidados por PRC_CONSOLIDAR_INDICADORES (só admin). */
export interface IndicadorCasa {
  homeId: string;
  casa: string;
  adesaoPct: number | null;
  variacaoPassosPct: number | null;
  alertasAbertos: number;
  atualizadoEm: string;
}

export interface IndicadoresResponse {
  engine: Engine;
  dataRef: string | null;
  casas: IndicadorCasa[];
}
