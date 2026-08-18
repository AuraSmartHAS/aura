/**
 * Contrato do cliente da API: rota, método, Bearer e tradução do envelope de erro.
 * O fetch é dublado — aqui se testa o cliente, não o servidor.
 */
import { api, BASE_URL, setToken } from '../api';

const respostaOk = (corpo: unknown) =>
  Promise.resolve({ ok: true, text: () => Promise.resolve(JSON.stringify(corpo)) } as Response);

const respostaErro = (status: number, code: string, message: string) =>
  Promise.resolve({
    ok: false,
    status,
    text: () => Promise.resolve(JSON.stringify({ error: { code, message } })),
  } as Response);

describe('cliente da API', () => {
  let fetchMock: jest.Mock;

  beforeEach(() => {
    fetchMock = jest.fn();
    global.fetch = fetchMock as unknown as typeof fetch;
    setToken(null);
  });

  it('aponta para o backend Spring em /api/v1', () => {
    expect(BASE_URL).toContain('/api/v1');
    expect(BASE_URL).toContain('8080');
  });

  it('login envia e-mail e senha e não manda Authorization', async () => {
    fetchMock.mockReturnValue(respostaOk({ token: 'jwt-1', role: 'cuidadora' }));

    const sessao = await api.login('ana@aura.com', 'aura1234');

    expect(sessao.token).toBe('jwt-1');
    const [url, init] = fetchMock.mock.calls[0];
    expect(url).toBe(`${BASE_URL}/auth/login`);
    expect(init.method).toBe('POST');
    expect(JSON.parse(init.body)).toEqual({ email: 'ana@aura.com', password: 'aura1234' });
    expect(init.headers.Authorization).toBeUndefined();
  });

  it('depois do setToken, toda chamada leva o Bearer', async () => {
    setToken('jwt-1');
    fetchMock.mockReturnValue(respostaOk([]));

    await api.homes();

    const [, init] = fetchMock.mock.calls[0];
    expect(init.headers.Authorization).toBe('Bearer jwt-1');
  });

  it('traduz o envelope de erro da API em mensagem de tela', async () => {
    fetchMock.mockReturnValue(
      respostaErro(422, 'CONSENT_REQUIRED', 'Aceite a Política de Privacidade antes de registrar dados de saúde.'),
    );

    await expect(api.recompute('casa-1')).rejects.toThrow(
      'Aceite a Política de Privacidade antes de registrar dados de saúde.',
    );
  });

  it('registrar quase-queda manda o sinal de mobilidade por auto-relato', async () => {
    setToken('jwt-1');
    fetchMock.mockReturnValue(respostaOk({ signalId: 's1' }));

    await api.registerSignal('casa-1', 'near_fall');

    const [url, init] = fetchMock.mock.calls[0];
    expect(url).toBe(`${BASE_URL}/signals`);
    expect(JSON.parse(init.body)).toEqual({
      homeId: 'casa-1',
      type: 'mobility',
      source: 'self_report',
      value: { event: 'near_fall' },
    });
  });

  it('aprovar recomendação usa a rota de aprovação — única porta do pedido', async () => {
    setToken('jwt-1');
    fetchMock.mockReturnValue(respostaOk({ orderId: 'o1', stage: 'approved' }));

    const pedido = await api.approve('rec-1');

    expect(fetchMock.mock.calls[0][0]).toBe(`${BASE_URL}/recommendations/rec-1/approve`);
    expect(pedido.stage).toBe('approved');
  });

  it('avançar pedido chama a rota do pedido', async () => {
    setToken('jwt-1');
    fetchMock.mockReturnValue(respostaOk({ stage: 'in_route', slaBreached: false }));

    const resultado = await api.advance('pedido-1');

    expect(fetchMock.mock.calls[0][0]).toBe(`${BASE_URL}/orders/pedido-1/advance`);
    expect(resultado.stage).toBe('in_route');
  });
});
