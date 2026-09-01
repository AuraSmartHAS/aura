/** Formatação da casa para números que vão à tela. */

/** Peso do fator com vírgula decimal — nunca "0.4" cru no telão. */
export function pesoBr(weight: number): string {
  return String(weight).replace('.', ',');
}
