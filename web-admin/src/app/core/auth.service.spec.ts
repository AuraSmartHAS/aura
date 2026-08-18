import { TestBed } from '@angular/core/testing';
import { AuthService } from './auth.service';

describe('AuthService', () => {
  let auth: AuthService;

  beforeEach(() => {
    localStorage.clear();
    TestBed.configureTestingModule({ providers: [AuthService] });
    auth = TestBed.inject(AuthService);
  });

  afterEach(() => localStorage.clear());

  it('começa deslogado quando não há nada guardado', () => {
    expect(auth.isLoggedIn()).toBeFalse();
    expect(auth.token()).toBeNull();
  });

  it('guarda token e papel, e reconhece o admin', () => {
    auth.save('jwt-123', 'admin');

    expect(auth.isLoggedIn()).toBeTrue();
    expect(auth.token()).toBe('jwt-123');
    expect(auth.isAdmin()).toBeTrue();
    expect(localStorage.getItem('aura.token')).toBe('jwt-123');
  });

  it('cuidadora não é admin', () => {
    auth.save('jwt-123', 'cuidadora');
    expect(auth.isAdmin()).toBeFalse();
  });

  it('limpar derruba a sessão e o armazenamento', () => {
    auth.save('jwt-123', 'cuidadora');
    auth.clear();

    expect(auth.isLoggedIn()).toBeFalse();
    expect(localStorage.getItem('aura.token')).toBeNull();
  });
});
