/**
 * Para onde o toque no aviso leva, e o toque que chega antes do login: guardado, entregue uma vez.
 */
import { deepLinkFor, isSos, PendingDeepLink, PUSH_CHANNELS, PushDestination } from '../pushRouting';

const sos = {
  kind: 'sos',
  homeId: 'home-1',
  emergencyId: 'em-1',
  state: 'dispatched',
  action: 'ack',
  lat: '-23.56',
  lng: '-46.65',
  address: 'Av. Paulista, 1000',
};

describe('deep link do aviso', () => {
  it('SOS abre a tela de socorro com o endereço e as coordenadas do aviso', () => {
    expect(deepLinkFor(sos)).toEqual({
      name: 'EmergencyAlert',
      params: { emergencyId: 'em-1', homeId: 'home-1', address: 'Av. Paulista, 1000', lat: -23.56, lng: -46.65 },
    });
  });

  it('o botão "Estou indo" abre a tela de socorro já confirmando', () => {
    const destino = deepLinkFor(sos, { ack: true });
    expect(destino?.name === 'EmergencyAlert' && destino.params.autoAck).toBe(true);
    // o toque no corpo do aviso só abre, não confirma por ninguém
    const toque = deepLinkFor(sos);
    expect(toque?.name === 'EmergencyAlert' && toque.params.autoAck).toBeUndefined();
  });

  it('SOS cancelado, pedido e recomendação abrem o painel', () => {
    expect(deepLinkFor({ kind: 'sos_cancelled', emergencyId: 'em-1' })).toEqual({ name: 'Dashboard' });
    expect(deepLinkFor({ kind: 'order', orderId: 'o-1' })).toEqual({ name: 'Dashboard' });
    expect(deepLinkFor({ kind: 'recommendation', recommendationId: 'r-1' })).toEqual({ name: 'Dashboard' });
  });

  it('aviso sem destino não navega', () => {
    expect(deepLinkFor({})).toBeNull();
    expect(deepLinkFor(null)).toBeNull();
  });

  it('coordenada ilegível fica de fora em vez de virar NaN', () => {
    const destino = deepLinkFor({ ...sos, lat: 'x' });
    expect(destino?.name === 'EmergencyAlert' && destino.params.lat).toBeUndefined();
  });

  it('os canais são os mesmos do backend e do app Flutter', () => {
    expect(PUSH_CHANNELS.sos.id).toBe('aura_sos');
    expect(PUSH_CHANNELS.geral.id).toBe('aura_geral');
    expect(isSos('sos_escalated')).toBe(true);
    expect(isSos('order')).toBe(false);
  });
});

describe('toque guardado até o login', () => {
  it('sem sessão guarda; com sessão o login entrega uma vez só', () => {
    let session = false;
    const navegou: PushDestination[] = [];
    const pending = new PendingDeepLink(() => session, (d) => navegou.push(d));

    pending.open(sos);
    expect(navegou).toHaveLength(0);

    session = true;
    expect(pending.take()?.name).toBe('EmergencyAlert');
    expect(pending.take()).toBeNull();
  });

  it('com sessão navega na hora', () => {
    const navegou: PushDestination[] = [];
    const pending = new PendingDeepLink(() => true, (d) => navegou.push(d));

    pending.open({ kind: 'order', orderId: 'o-1' });

    expect(navegou).toEqual([{ name: 'Dashboard' }]);
    expect(pending.take()).toBeNull();
  });

  it('"Estou indo" sem sessão espera o login e confirma depois dele', () => {
    const pending = new PendingDeepLink(() => false, () => undefined);
    pending.open(sos, true);
    const destino = pending.take();
    expect(destino?.name === 'EmergencyAlert' && destino.params.autoAck).toBe(true);
  });

  it('logout descarta o destino guardado', () => {
    const pending = new PendingDeepLink(() => false, () => undefined);
    pending.open(sos);
    pending.clear();
    expect(pending.take()).toBeNull();
  });
});
