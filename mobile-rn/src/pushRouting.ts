import type { RootStackParamList } from './navigation';

/**
 * Canais Android do AURA — os mesmos ids do app Flutter e do `FcmService` do backend, que escolhe
 * o canal em cada aviso. Canal que o app não criou faz o Android cair num canal genérico, sem som.
 */
export const PUSH_CHANNELS = {
  sos: { id: 'aura_sos', name: 'Pedidos de ajuda', description: 'Avisos de socorro da casa: tocam e vibram mesmo no silencioso.' },
  geral: { id: 'aura_geral', name: 'Pedidos e recomendações', description: 'Andamento de pedidos e novas recomendações.' },
} as const;

/** Categoria do SOS em aberto (backend `FcmService.CATEGORY_SOS_ACK`) e a ação do botão. */
export const SOS_ACK_CATEGORY = 'aura_sos_ack';
export const ACK_ACTION = 'ack';

/** `sos`, `sos_escalated` e `sos_cancelled` são avisos de crise. */
export function isSos(kind: unknown): boolean {
  return typeof kind === 'string' && kind.startsWith('sos');
}

export type PushDestination =
  | { name: 'EmergencyAlert'; params: RootStackParamList['EmergencyAlert'] }
  | { name: 'Dashboard' };

function text(data: Record<string, unknown>, key: string): string | undefined {
  const value = data[key];
  return typeof value === 'string' && value.length > 0 ? value : undefined;
}

function num(data: Record<string, unknown>, key: string): number | undefined {
  const raw = text(data, key);
  const value = raw === undefined ? NaN : Number(raw);
  return Number.isFinite(value) ? value : undefined;
}

/**
 * Para onde o toque no aviso leva. Pedido e recomendação abrem o painel: neste app o pedido vive
 * dentro do Care-Chain, que precisa do escore de origem — o painel é a porta para ele. O SOS
 * cancelado também vai ao painel: a tela de socorro ofereceria "Estou indo" a um pedido encerrado.
 */
export function deepLinkFor(
  data: Record<string, unknown> | null | undefined,
  options: { ack?: boolean } = {},
): PushDestination | null {
  if (!data) return null;
  const kind = text(data, 'kind');
  const emergencyId = text(data, 'emergencyId');
  if (emergencyId) {
    if (kind === 'sos_cancelled') return { name: 'Dashboard' };
    return {
      name: 'EmergencyAlert',
      params: {
        emergencyId,
        homeId: text(data, 'homeId'),
        address: text(data, 'address'),
        lat: num(data, 'lat'),
        lng: num(data, 'lng'),
        ...(options.ack ? { autoAck: true } : {}),
      },
    };
  }
  if (text(data, 'orderId') || text(data, 'recommendationId') || kind === 'order' || kind === 'recommendation') {
    return { name: 'Dashboard' };
  }
  return null;
}

/**
 * Guarda o toque que chegou sem sessão (app aberto pelo aviso cai no login) e só o entrega depois
 * do login. Sem isto, abrir o pedido de ajuda antes do login daria 401 na hora de dizer "Estou indo".
 */
export class PendingDeepLink {
  private pending: PushDestination | null = null;

  constructor(
    private readonly hasSession: () => boolean,
    private readonly navigate: (destination: PushDestination) => void,
  ) {}

  /** `ack`: veio do botão "Estou indo" — a tela de socorro confirma ao abrir. */
  open(data: Record<string, unknown> | null | undefined, ack = false): void {
    const destination = deepLinkFor(data, { ack });
    if (!destination) return;
    if (this.hasSession()) {
      this.navigate(destination);
    } else {
      this.pending = destination;
    }
  }

  /** Uma vez só: quem chama é o login, logo depois de entrar. */
  take(): PushDestination | null {
    const destination = this.pending;
    this.pending = null;
    return destination;
  }

  clear(): void {
    this.pending = null;
  }
}
