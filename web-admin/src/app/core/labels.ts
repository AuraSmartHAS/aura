/**
 * Dicionário único de rótulos de tela para os códigos que a API fala.
 * Casa e Operação importam daqui: um estágio novo se traduz num lugar só,
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

/** Risco que o item do catálogo mitiga — cobre também as tags do catálogo curado (produtos-leroy.csv). */
export const RISK_TAG_LABELS: Record<string, string> = {
  fall_bathroom: 'Queda no banheiro',
  fall_general: 'Queda em casa',
  night_trips: 'Idas noturnas ao banheiro',
  mobility: 'Mobilidade',
  cognition: 'Cognição',
  environment: 'Ambiente',
  dexterity: 'Destreza das mãos',
  daily_living: 'Rotina diária',
  emergency: 'Emergência',
  home_security: 'Segurança da casa',
  caregiver_monitoring: 'Acompanhamento remoto',
  accessibility_voice: 'Casa por voz',
  hydration: 'Hidratação',
  medication_adherence: 'Adesão à medicação',
};

/** Itens do checklist de segurança da casa; cada um entra no cálculo do risco. */
export const CHECKLIST_LABELS: Record<string, string> = {
  grab_bar_bathroom: 'Barra de apoio no banheiro',
  anti_slip_floor: 'Piso antiderrapante',
  night_light: 'Iluminação noturna',
  gas_detector: 'Detector de gás/fumaça',
  air_purifier: 'Purificador de ar',
};

/** Dimensão observada do sinal (ver SignalType no backend). */
export const SIGNAL_TYPE_LABELS: Record<string, string> = {
  mobility: 'Mobilidade',
  sleep: 'Sono',
  cognition: 'Cognição',
  mood: 'Humor',
  environment: 'Ambiente',
  adherence: 'Adesão ao tratamento',
  vitals: 'Sinais vitais',
};

/** Origem do sinal (ver SignalSource no backend). */
export const SIGNAL_SOURCE_LABELS: Record<string, string> = {
  voice: 'Assistente de voz',
  self_report: 'Relato da pessoa ou cuidadora',
  usage: 'Uso do aplicativo',
  wearable: 'Dispositivo vestível',
};

/** Vocabulário de eventos conhecidos (ver scoring-weights.yml no backend). */
export const SIGNAL_EVENT_LABELS: Record<string, string> = {
  near_fall: 'Queda ou quase-queda registrada',
  dizziness: 'Tontura relatada',
  night_trip: 'Idas noturnas ao banheiro',
  confusion: 'Confusão ou repetição na fala registrada',
  poor_air: 'Qualidade do ar ruim relatada',
};

/** Local onde o evento ocorreu, quando informado. */
export const SIGNAL_PLACE_LABELS: Record<string, string> = {
  bathroom: 'banheiro',
};

/** Nomes de fator do escore explicável (ver scoring-weights.yml no backend). */
export const SCORE_FACTOR_LABELS: Record<string, string> = {
  near_fall_reported: 'quase-queda relatada',
  no_grab_bar: 'ausência de barra de apoio',
  anti_slip_floor: 'ausência de piso antiderrapante',
  dizziness_bath: 'tontura ao banho',
  night_trips_reported: 'idas noturnas frequentes',
  poor_night_lighting: 'iluminação noturna insuficiente',
  confusion_reported: 'confusão/repetição na fala',
  no_gas_detector: 'sem detector de gás/fumaça',
  poor_air_reported: 'qualidade do ar ruim relatada',
  no_air_purifier: 'sem purificador de ar',
};

/** Peso do aviso como a família lê: o que pede olhar agora e o que é só acompanhamento. */
export const ALERT_SEVERITY_LABELS: Record<string, string> = {
  alta: 'Importante',
  atencao: 'Atenção',
  info: 'Para acompanhar',
};

/** Fallback consciente: código desconhecido aparece cru, nunca some da tela. */
export function stageLabel(stage: string): string {
  return STAGE_LABELS[stage] ?? stage;
}

export function recommendationStatusLabel(status: string): string {
  return RECOMMENDATION_STATUS_LABELS[status] ?? status;
}

export function riskTagLabel(tag: string | null): string {
  return tag ? (RISK_TAG_LABELS[tag] ?? tag) : '';
}

/**
 * "2026-10-04" -> "04/10". Data local sem hora não pode passar pelo pipe date: ele a lê como
 * meia-noite UTC e, em São Paulo, mostraria o dia anterior.
 */
export function diaMes(isoDate: string | null | undefined): string {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(isoDate ?? '');
  return m ? `${m[3]}/${m[2]}` : '';
}
