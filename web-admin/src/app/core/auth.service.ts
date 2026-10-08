import { HttpBackend, HttpClient } from '@angular/common/http';
import { Injectable, Injector, computed, inject, signal } from '@angular/core';
import { Observable, finalize, map, shareReplay, throwError } from 'rxjs';
import { environment } from '../../environments/environment';
import { Role, TokenResponse } from './models';

const TOKEN_KEY = 'aura.token';
const ROLE_KEY = 'aura.role';
const REFRESH_KEY = 'aura.refreshToken';

export const SESSION_EXPIRED_MESSAGE = 'Sua sessão expirou. Entre novamente.';

/** Sessão do painel: o par de JWTs vem do backend e fica no localStorage. */
@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly tokenSignal = signal<string | null>(localStorage.getItem(TOKEN_KEY));
  private readonly roleSignal = signal<Role | null>(localStorage.getItem(ROLE_KEY) as Role | null);
  private readonly noticeSignal = signal<string | null>(null);

  /**
   * HttpClient sem interceptores: o refresh não pode passar pelo próprio interceptor que o
   * dispara (nem receber o Bearer vencido, nem tentar outro refresh se falhar).
   */
  private readonly injector = inject(Injector);
  private rawHttp: HttpClient | null = null;
  /** Refresh em andamento, compartilhado por todas as requisições que receberam 401 juntas. */
  private refreshing: Observable<string> | null = null;

  readonly token = this.tokenSignal.asReadonly();
  readonly role = this.roleSignal.asReadonly();
  readonly isLoggedIn = computed(() => this.tokenSignal() !== null);
  readonly isAdmin = computed(() => this.roleSignal() === 'admin');

  save(token: string, role: Role, refreshToken?: string | null): void {
    localStorage.setItem(TOKEN_KEY, token);
    localStorage.setItem(ROLE_KEY, role);
    if (refreshToken) {
      localStorage.setItem(REFRESH_KEY, refreshToken);
    }
    this.tokenSignal.set(token);
    this.roleSignal.set(role);
    this.noticeSignal.set(null);
  }

  refreshToken(): string | null {
    return localStorage.getItem(REFRESH_KEY);
  }

  clear(): void {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(ROLE_KEY);
    localStorage.removeItem(REFRESH_KEY);
    this.tokenSignal.set(null);
    this.roleSignal.set(null);
  }

  /**
   * Troca o refresh token guardado por um par novo e devolve o access token novo. Chamadas
   * simultâneas recebem o mesmo refresh em andamento — um único POST /auth/refresh.
   */
  refresh(): Observable<string> {
    if (this.refreshing) {
      return this.refreshing;
    }
    const refreshToken = this.refreshToken();
    if (!refreshToken) {
      return throwError(() => new Error('Sem refresh token guardado.'));
    }
    this.rawHttp ??= new HttpClient(this.injector.get(HttpBackend));
    this.refreshing = this.rawHttp
      .post<TokenResponse>(`${environment.apiBaseUrl}/auth/refresh`, { refreshToken })
      .pipe(
        map((res) => {
          this.save(res.token, res.role, res.refreshToken);
          return res.token;
        }),
        finalize(() => (this.refreshing = null)),
        shareReplay({ bufferSize: 1, refCount: false }),
      );
    return this.refreshing;
  }

  /**
   * Encerra a sessão por expiração e deixa o aviso para a tela de login. Devolve false se já não
   * havia sessão — várias requisições falhando juntas avisam e redirecionam uma vez só.
   */
  expire(): boolean {
    if (!this.isLoggedIn()) {
      return false;
    }
    this.clear();
    this.noticeSignal.set(SESSION_EXPIRED_MESSAGE);
    return true;
  }

  /** Lê e descarta o aviso de sessão expirada: aparece uma vez. */
  consumeNotice(): string | null {
    const notice = this.noticeSignal();
    this.noticeSignal.set(null);
    return notice;
  }
}
