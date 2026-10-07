import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { HttpClient, provideHttpClient, withInterceptors } from '@angular/common/http';
import { TestBed } from '@angular/core/testing';
import { Router } from '@angular/router';
import { environment } from '../../environments/environment';
import { authInterceptor } from './auth.interceptor';
import { AuthService, SESSION_EXPIRED_MESSAGE } from './auth.service';

const API = environment.apiBaseUrl;
const EXPIRED = { error: { code: 'TOKEN_EXPIRED', message: 'Token expirado — use o refresh.' } };
const UNAUTHORIZED_401 = { status: 401, statusText: 'Unauthorized' };

describe('authInterceptor', () => {
  let http: HttpClient;
  let mock: HttpTestingController;
  let auth: AuthService;
  let router: jasmine.SpyObj<Router>;

  beforeEach(() => {
    localStorage.clear();
    router = jasmine.createSpyObj('Router', ['navigate']);

    TestBed.configureTestingModule({
      providers: [
        AuthService,
        { provide: Router, useValue: router },
        provideHttpClient(withInterceptors([authInterceptor])),
        provideHttpClientTesting(),
      ],
    });
    http = TestBed.inject(HttpClient);
    mock = TestBed.inject(HttpTestingController);
    auth = TestBed.inject(AuthService);
  });

  afterEach(() => {
    mock.verify();
    localStorage.clear();
  });

  it('não manda Authorization quando não há sessão', () => {
    http.get('/api/v1/catalog').subscribe();

    const req = mock.expectOne('/api/v1/catalog');
    expect(req.request.headers.has('Authorization')).toBeFalse();
    req.flush([]);
  });

  it('anexa o Bearer quando há token', () => {
    auth.save('jwt-123', 'cuidadora');
    http.get('/api/v1/homes').subscribe();

    const req = mock.expectOne('/api/v1/homes');
    expect(req.request.headers.get('Authorization')).toBe('Bearer jwt-123');
    req.flush([]);
  });

  it('em 401 derruba a sessão e volta para o login', () => {
    auth.save('jwt-expirado', 'cuidadora');
    http.get('/api/v1/homes').subscribe({ error: () => undefined });

    mock.expectOne('/api/v1/homes').flush(
      { error: { code: 'TOKEN_EXPIRED', message: 'Token expirado' } },
      { status: 401, statusText: 'Unauthorized' },
    );

    expect(auth.isLoggedIn()).toBeFalse();
    expect(router.navigate).toHaveBeenCalledWith(['/login']);
  });

  it('403 não derruba a sessão — é falta de permissão, não de autenticação', () => {
    auth.save('jwt-123', 'cuidadora');
    http.get('/api/v1/ops/kpis').subscribe({ error: () => undefined });

    mock.expectOne('/api/v1/ops/kpis').flush(
      { error: { code: 'FORBIDDEN', message: 'Acesso negado' } },
      { status: 403, statusText: 'Forbidden' },
    );

    expect(auth.isLoggedIn()).toBeTrue();
    expect(router.navigate).not.toHaveBeenCalled();
  });

  for (const route of ['login', 'signup', 'refresh']) {
    it(`não anexa o Bearer em /auth/${route}, mesmo com um token velho guardado`, () => {
      auth.save('jwt-velho', 'cuidadora', 'refresh-velho');
      http.post(`${API}/auth/${route}`, {}).subscribe();

      const req = mock.expectOne(`${API}/auth/${route}`);
      expect(req.request.headers.has('Authorization')).toBeFalse();
      req.flush({});
    });
  }

  it('401 do próprio login é resposta (senha errada), não derruba nem redireciona', () => {
    http.post(`${API}/auth/login`, {}).subscribe({ error: () => undefined });

    mock
      .expectOne(`${API}/auth/login`)
      .flush(
        { error: { code: 'INVALID_CREDENTIALS', message: 'E-mail ou senha incorretos.' } },
        UNAUTHORIZED_401,
      );
    expect(router.navigate).not.toHaveBeenCalled();
    expect(mock.match(`${API}/auth/refresh`).length).toBe(0);
  });

  it('TOKEN_EXPIRED: renova com o refresh guardado e repete a requisição original', () => {
    auth.save('jwt-vencido', 'cuidadora', 'refresh-1');
    let result: unknown;
    http.get(`${API}/homes`).subscribe((body) => (result = body));

    mock.expectOne(`${API}/homes`).flush(EXPIRED, UNAUTHORIZED_401);

    const refresh = mock.expectOne(`${API}/auth/refresh`);
    expect(refresh.request.method).toBe('POST');
    expect(refresh.request.body).toEqual({ refreshToken: 'refresh-1' });
    expect(refresh.request.headers.has('Authorization')).toBeFalse();
    refresh.flush({ token: 'jwt-novo', role: 'cuidadora', refreshToken: 'refresh-2' });

    const retried = mock.expectOne(`${API}/homes`);
    expect(retried.request.headers.get('Authorization')).toBe('Bearer jwt-novo');
    retried.flush([{ id: 'h1' }]);

    expect(result).toEqual([{ id: 'h1' }]);
    expect(auth.token()).toBe('jwt-novo');
    expect(auth.refreshToken()).toBe('refresh-2');
    expect(router.navigate).not.toHaveBeenCalled();
  });

  it('várias requisições com 401 ao mesmo tempo compartilham um único refresh', () => {
    auth.save('jwt-vencido', 'cuidadora', 'refresh-1');
    const results: unknown[] = [];
    http.get(`${API}/homes`).subscribe((b) => results.push(b));
    http.get(`${API}/catalog`).subscribe((b) => results.push(b));
    http.get(`${API}/ops/kpis`).subscribe((b) => results.push(b));

    mock.expectOne(`${API}/homes`).flush(EXPIRED, UNAUTHORIZED_401);
    mock.expectOne(`${API}/catalog`).flush(EXPIRED, UNAUTHORIZED_401);

    const refreshes = mock.match(`${API}/auth/refresh`);
    expect(refreshes.length).toBe(1);
    refreshes[0].flush({ token: 'jwt-novo', role: 'cuidadora', refreshToken: 'refresh-2' });

    // a terceira voltou com 401 depois que o refresh já tinha terminado: só repete, sem outro refresh
    mock.expectOne(`${API}/ops/kpis`).flush(EXPIRED, UNAUTHORIZED_401);
    expect(mock.match(`${API}/auth/refresh`).length).toBe(0);

    for (const url of ['homes', 'catalog', 'ops/kpis']) {
      const retried = mock.expectOne(`${API}/${url}`);
      expect(retried.request.headers.get('Authorization')).toBe('Bearer jwt-novo');
      retried.flush([url]);
    }
    expect(results.length).toBe(3);
  });

  it('refresh recusado: limpa a sessão e vai ao login com o aviso, uma vez só', () => {
    auth.save('jwt-vencido', 'cuidadora', 'refresh-vencido');
    const errors: number[] = [];
    http.get(`${API}/homes`).subscribe({ error: (e) => errors.push(e.status) });
    http.get(`${API}/catalog`).subscribe({ error: (e) => errors.push(e.status) });

    mock.expectOne(`${API}/homes`).flush(EXPIRED, UNAUTHORIZED_401);
    mock.expectOne(`${API}/catalog`).flush(EXPIRED, UNAUTHORIZED_401);
    mock.expectOne(`${API}/auth/refresh`).flush(EXPIRED, UNAUTHORIZED_401);

    expect(errors).toEqual([401, 401]);
    expect(auth.isLoggedIn()).toBeFalse();
    expect(auth.refreshToken()).toBeNull();
    expect(router.navigate).toHaveBeenCalledOnceWith(['/login']);
    expect(auth.consumeNotice()).toBe(SESSION_EXPIRED_MESSAGE);
    expect(auth.consumeNotice()).toBeNull();
  });

  it('401 UNAUTHORIZED (sessão encerrada pela troca de senha) não tenta refresh: vai direto ao login', () => {
    auth.save('jwt-revogado', 'cuidadora', 'refresh-revogado');
    http.get(`${API}/homes`).subscribe({ error: () => undefined });

    mock
      .expectOne(`${API}/homes`)
      .flush(
        { error: { code: 'UNAUTHORIZED', message: 'Sessão encerrada — entre novamente.' } },
        UNAUTHORIZED_401,
      );

    expect(mock.match(`${API}/auth/refresh`).length).toBe(0);
    expect(auth.isLoggedIn()).toBeFalse();
    expect(router.navigate).toHaveBeenCalledOnceWith(['/login']);
    expect(auth.consumeNotice()).toBe(SESSION_EXPIRED_MESSAGE);
  });

  it('se a repetição depois do refresh ainda voltar 401, encerra a sessão sem novo refresh', () => {
    auth.save('jwt-vencido', 'cuidadora', 'refresh-1');
    http.get(`${API}/homes`).subscribe({ error: () => undefined });

    mock.expectOne(`${API}/homes`).flush(EXPIRED, UNAUTHORIZED_401);
    mock
      .expectOne(`${API}/auth/refresh`)
      .flush({ token: 'jwt-novo', role: 'cuidadora', refreshToken: 'r2' });
    mock.expectOne(`${API}/homes`).flush(EXPIRED, UNAUTHORIZED_401);

    expect(mock.match(`${API}/auth/refresh`).length).toBe(0);
    expect(auth.isLoggedIn()).toBeFalse();
    expect(router.navigate).toHaveBeenCalledOnceWith(['/login']);
  });
});
