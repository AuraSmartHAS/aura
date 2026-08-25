/**
 * AURA Care-Chain design system — paleta e tipos compartilhados com o app Flutter
 * (`mobile/lib/core/theme`) e o painel Angular (`web-admin/src/styles.css`).
 *
 * Petrol azul como marca/ação, verde de cuidado para "seguro/confirma", neutros
 * quentes (não branco frio) e severidade clínica (verde · âmbar · vermelho).
 * Tipografia: Bricolage Grotesque para títulos, Atkinson Hyperlegible (Braille
 * Institute, alta legibilidade) para todo o corpo de texto — acessibilidade AA.
 */
export const theme = {
  // Brand (petrol)
  primary: '#1A5276',
  primaryLight: '#2E6E91',
  primaryDark: '#123C56',
  ink: '#10303C',

  // Care green (seguro / confirma / em dia)
  careGreen: '#148F77',
  confirm: '#0E7561',
  secondary: '#148F77',
  secondaryLight: '#2FA890',
  secondaryDark: '#0E7561',

  // Neutros quentes
  bg: '#F7F5F1',
  surface: '#FFFFFF',
  surfaceAlt: '#EFEBE4',
  surfaceTinted: '#F1EEE8',

  // Texto
  textStrong: '#10303C',
  text: '#4E5D63',
  muted: '#657076',

  // Linhas
  border: '#E3DED5',
  focus: '#1A5276',

  // Severidade / status
  danger: '#C0392B',
  success: '#148F77',
  accent: '#9A6109', // âmbar de atenção (era laranja do tema antigo)
  info: '#1A5276',

  hint: '#657076',
} as const;

export const levelColor: Record<string, string> = {
  low: theme.success,
  medium: theme.accent,
  high: theme.danger,
};

/** Espaçamento em grade de 4pt (espelha `AppDimensions` do Flutter). */
export const spacing = {
  xs: 4,
  sm: 8,
  md: 16,
  lg: 24,
  xl: 32,
  xxl: 48,
} as const;

export const radius = {
  sm: 8,
  md: 12,
  lg: 16,
} as const;

/** Alvo mínimo de toque, WCAG 2.5.5. */
export const minTouchTarget = 48;

/** Fontes carregadas via `useFonts` em `App.tsx` (expo-google-fonts). */
export const fontFamily = {
  display: 'BricolageGrotesque_700Bold',
  displaySemibold: 'BricolageGrotesque_600SemiBold',
  body: 'AtkinsonHyperlegible_400Regular',
  bodyBold: 'AtkinsonHyperlegible_700Bold',
} as const;
