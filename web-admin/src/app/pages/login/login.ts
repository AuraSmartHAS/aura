import { CommonModule } from '@angular/common';
import { Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { ApiService } from '../../core/api.service';
import { AuthService } from '../../core/auth.service';
import { errorMessage } from '../../core/error-message';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './login.html',
})
export class LoginComponent {
  private readonly api = inject(ApiService);
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);

  // ligados ao formulário com [(ngModel)]
  email = 'ana@aura.com';
  password = 'aura1234';

  readonly loading = signal(false);
  readonly error = signal<string | null>(null);

  submit(): void {
    this.loading.set(true);
    this.error.set(null);

    this.api.login(this.email, this.password).subscribe({
      next: (res) => {
        this.auth.save(res.token, res.role);
        this.loading.set(false);
        this.router.navigate([res.role === 'admin' ? '/admin' : '/home']);
      },
      error: (err) => {
        this.loading.set(false);
        this.error.set(errorMessage(err, 'E-mail ou senha incorretos.'));
      },
    });
  }

  useDemo(email: string): void {
    this.email = email;
    this.password = 'aura1234';
  }
}
