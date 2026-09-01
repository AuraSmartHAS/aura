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

/** Papel da conta como a pessoa entende, não como o banco grava. */
export const ROLE_LABELS: Record<string, string> = {
  admin: 'Operação',
  cuidadora: 'Cuidadora',
  profissional: 'Profissional',
  paciente: 'Paciente',
};

/** Dimensões do escore explicável (ver scoring-weights.yml no backend). */
export const DIMENSION_LABELS: Record<string, string> = {
  mobility: 'Mobilidade',
  sleep: 'Sono',
  cognition: 'Cognição',
  environment: 'Ambiente',
  mood: 'Humor',
};

/** O nível fala com a família: estado da casa, não nota de prova — sem sigla, sem percentual. */
export const RISK_LEVEL_LABELS: Record<string, string> = {
  low: 'Tudo certo',
  medium: 'Atenção',
  high: 'Risco alto',
};

/** Fallback consciente: código desconhecido aparece cru, nunca some da tela. */
export function stageLabel(stage: string): string {
  return STAGE_LABELS[stage] ?? stage;
}

export function recommendationStatusLabel(status: string): string {
  return RECOMMENDATION_STATUS_LABELS[status] ?? status;
}
