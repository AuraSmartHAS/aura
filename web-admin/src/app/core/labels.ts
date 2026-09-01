/**
 * Dicionário único de rótulos de tela para os códigos que a API fala.
 * Casa e Torre importam daqui: um estágio novo se traduz num lugar só,
 * e nenhum "in_route" volta a vazar em inglês no telão.
 */
export const STAGE_LABELS: Record<string, string> = {
  approved: 'Aprovado',
  sourcing: 'Separando',
  in_route: 'Em rota',
  delivered: 'Entregue',
  installed: 'Instalado',
  returned: 'Devolvido',
};

export const RECOMMENDATION_STATUS_LABELS: Record<string, string> = {
  recommended: 'Recomendado',
  approved: 'Aprovado',
  rejected: 'Recusado',
};

/** Dimensões do escore explicável (ver scoring-weights.yml no backend). */
export const DIMENSION_LABELS: Record<string, string> = {
  mobility: 'Mobilidade',
  sleep: 'Sono',
  cognition: 'Cognição',
  environment: 'Ambiente',
  mood: 'Humor',
};

export const RISK_LEVEL_LABELS: Record<string, string> = {
  low: 'baixo',
  medium: 'médio',
  high: 'ALTO',
};

/** Fallback consciente: código desconhecido aparece cru, nunca some da tela. */
export function stageLabel(stage: string): string {
  return STAGE_LABELS[stage] ?? stage;
}

export function recommendationStatusLabel(status: string): string {
  return RECOMMENDATION_STATUS_LABELS[status] ?? status;
}
