/**
 * Contrato do cliente da API: rota, método, Bearer e tradução do envelope de erro.
 * O fetch é dublado — aqui se testa o cliente, não o servidor.
 */
import { api, BASE_URL, isAdmin, isSessionExpired, SESSION_EXPIRED_MESSAGE, setRole, setToken } from '../api';

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
    globalThis.fetch = fetchMock as unknown as typeof fetch;
    setToken(null);
    setRole(null);
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

  it('sinais, remédios e SOS ativo: rotas da família, todas com Bearer', async () => {
    setToken('jwt-1');
    fetchMock.mockReturnValue(respostaOk([]));

    await api.signals('casa-1', new Date('2026-10-06T03:00:00.000Z'), 30);
    await api.medications('casa-1');
    await api.activeEmergency('casa-1');

    expect(fetchMock.mock.calls.map((c) => c[0])).toEqual([
      `${BASE_URL}/homes/casa-1/signals?limit=30&from=2026-10-06T03%3A00%3A00.000Z`,
      `${BASE_URL}/homes/casa-1/medications`,
      `${BASE_URL}/homes/casa-1/emergencies/active`,
    ]);
    for (const [, init] of fetchMock.mock.calls) {
      expect(init.headers.Authorization).toBe('Bearer jwt-1');
    }
  });

  it('SOS ativo: 204 sem corpo vira null, "nada acontecendo"', async () => {
    setToken('jwt-1');
    fetchMock.mockReturnValue(Promise.resolve({ ok: true, status: 204, text: () => Promise.resolve('') } as Response));

    expect(await api.activeEmergency('casa-1')).toBeNull();
  });

  it('"estou indo" é um POST em /emergencies/{id}/ack', async () => {
    setToken('jwt-1');
    fetchMock.mockReturnValue(respostaOk({ emergencyId: 'em-1', state: 'acknowledged', acknowledgedByName: 'Ana' }));

    const resposta = await api.acknowledgeEmergency('em-1');

    const [url, init] = fetchMock.mock.calls[0];
    expect(url).toBe(`${BASE_URL}/emergencies/em-1/ack`);
    expect(init.method).toBe('POST');
    expect(resposta.state).toBe('acknowledged');
  });

  it('cadastrar, editar e excluir medicamento usam as rotas da casa e do medicamento', async () => {
    setToken('jwt-1');
    fetchMock.mockReturnValue(respostaOk({ id: 'med-1' }));

    await api.createMedication('casa-1', { name: 'Losartana', schedule: ['08:00'] });
    await api.updateMedication('med-1', { name: 'Losartana', dosage: '', schedule: [] });
    fetchMock.mockReturnValue(respostaOk({ deleted: true }));
    const resposta = await api.deleteMedication('med-1');

    const chamadas = fetchMock.mock.calls.map(([url, init]) => [init.method, url]);
    expect(chamadas).toEqual([
      ['POST', `${BASE_URL}/homes/casa-1/medications`],
      ['PUT', `${BASE_URL}/medications/med-1`],
      ['DELETE', `${BASE_URL}/medications/med-1`],
    ]);
    expect(JSON.parse(fetchMock.mock.calls[0][1].body)).toEqual({ name: 'Losartana', schedule: ['08:00'] });
    expect(resposta.deleted).toBe(true);
  });

  it('confirmações de dose pedem type=adherence com o recorte de data', async () => {
    setToken('jwt-1');
    fetchMock.mockReturnValue(respostaOk([]));

    await api.signals('casa-1', new Date('2026-10-07T03:00:00.000Z'), 200, 'adherence');

    expect(fetchMock.mock.calls[0][0]).toBe(
      `${BASE_URL}/homes/casa-1/signals?limit=200&type=adherence&from=2026-10-07T03%3A00%3A00.000Z`,
    );
  });

  it('sinais sem recorte de data pedem o limite e nada mais', async () => {
    setToken('jwt-1');
    fetchMock.mockReturnValue(respostaOk([]));

    await api.signals('casa-1');

    expect(fetchMock.mock.calls[0][0]).toBe(`${BASE_URL}/homes/casa-1/signals?limit=200`);
  });

  it('401 COM sessão aberta é "sua sessão expirou" — não "sem conexão" nem a mensagem crua', async () => {
    setToken('jwt-1');
    fetchMock.mockReturnValue(respostaErro(401, 'TOKEN_EXPIRED', 'Token expirado — use o refresh.'));

    const erro = await api.medications('casa-1').catch((e) => e);

    expect(isSessionExpired(erro)).toBe(true);
    expect(erro.message).toBe(SESSION_EXPIRED_MESSAGE);
  });

  it('401 SEM sessão (login com senha errada) mantém a mensagem do servidor', async () => {
    fetchMock.mockReturnValue(respostaErro(401, 'INVALID_CREDENTIALS', 'E-mail ou senha inválidos.'));

    const erro = await api.login('ana@aura.com', 'errada').catch((e) => e);

    expect(isSessionExpired(erro)).toBe(false);
    expect(erro.message).toBe('E-mail ou senha inválidos.');
  });

  it('login com senha errada NUNCA vira "sessão expirou", mesmo com um token vencido na memória', async () => {
    setToken('jwt-vencido');
    fetchMock.mockReturnValue(respostaErro(401, 'INVALID_CREDENTIALS', 'E-mail ou senha inválidos.'));

    const erro = await api.login('ana@aura.com', 'errada').catch((e) => e);

    expect(isSessionExpired(erro)).toBe(false);
    expect(erro.message).toBe('E-mail ou senha inválidos.');
  });

  it('200 com corpo que não é JSON (portal cativo) é erro claro, não um null que quebra a tela', async () => {
    setToken('jwt-1');
    fetchMock.mockReturnValue(
      Promise.resolve({ ok: true, status: 200, text: () => Promise.resolve('<html>Entre no Wi-Fi</html>') } as Response),
    );

    const erro = await api.homes().catch((e) => e);

    expect(erro.message).toBe('Resposta inesperada do servidor.');
  });

  it('corpo de erro que não é JSON (página de proxy) vira mensagem humana, não "Unexpected token <"', async () => {
    setToken('jwt-1');
    fetchMock.mockReturnValue(
      Promise.resolve({ ok: false, status: 502, text: () => Promise.resolve('<html>Bad gateway</html>') } as Response),
    );

    const erro = await api.medications('casa-1').catch((e) => e);

    expect(erro.message).toBe('Falha na comunicação com o servidor.');
  });

  it('desfecho do SOS é um GET aberto em /emergencies/{id}', async () => {
    setToken('jwt-1');
    fetchMock.mockReturnValue(respostaOk({ emergencyId: 'em-1', state: 'acknowledged' }));

    const resposta = await api.emergencyOutcome('em-1');

    const [url, init] = fetchMock.mock.calls[0];
    expect(url).toBe(`${BASE_URL}/emergencies/em-1`);
    expect(init.method).toBeUndefined();
    expect(resposta.state).toBe('acknowledged');
  });

  it('só o papel admin pode avançar a cadeia (o backend nega aos demais)', () => {
    expect(isAdmin()).toBe(false);

    setRole('cuidadora');
    expect(isAdmin()).toBe(false);

    setRole('paciente');
    expect(isAdmin()).toBe(false);

    setRole('admin');
    expect(isAdmin()).toBe(true);

    setRole(null);
    expect(isAdmin()).toBe(false);
  });
});
