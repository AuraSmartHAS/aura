import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { HttpClient, provideHttpClient, withInterceptors } from '@angular/common/http';
import { TestBed } from '@angular/core/testing';
import { Router } from '@angular/router';
import { authInterceptor } from './auth.interceptor';
import { AuthService } from './auth.service';

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
});
