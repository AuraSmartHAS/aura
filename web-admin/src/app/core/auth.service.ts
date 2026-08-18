import { Injectable, computed, signal } from '@angular/core';
import { Role } from './models';

const TOKEN_KEY = 'aura.token';
const ROLE_KEY = 'aura.role';

/** Sessão do painel: o JWT vem do backend e fica no localStorage. */
@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly tokenSignal = signal<string | null>(localStorage.getItem(TOKEN_KEY));
  private readonly roleSignal = signal<Role | null>(localStorage.getItem(ROLE_KEY) as Role | null);

  readonly token = this.tokenSignal.asReadonly();
  readonly role = this.roleSignal.asReadonly();
  readonly isLoggedIn = computed(() => this.tokenSignal() !== null);
  readonly isAdmin = computed(() => this.roleSignal() === 'admin');

  save(token: string, role: Role): void {
    localStorage.setItem(TOKEN_KEY, token);
    localStorage.setItem(ROLE_KEY, role);
    this.tokenSignal.set(token);
    this.roleSignal.set(role);
  }

  clear(): void {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(ROLE_KEY);
    this.tokenSignal.set(null);
    this.roleSignal.set(null);
  }
}
