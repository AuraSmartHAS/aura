/** Paleta compartilhada com o app Flutter e com o painel Angular. */
export const theme = {
  bg: '#0d1117',
  surface: '#161b22',
  surfaceAlt: '#1c2430',
  border: '#21262d',
  text: '#c9d1d9',
  textStrong: '#f0f6fc',
  muted: '#8b949e',
  accent: '#f0883e',
  info: '#58a6ff',
  danger: '#f85149',
  success: '#3fb950',
};

export const levelColor: Record<string, string> = {
  low: theme.success,
  medium: theme.accent,
  high: theme.danger,
};
