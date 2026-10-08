import { HttpErrorResponse, HttpInterceptorFn, HttpRequest } from '@angular/common/http';
import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { catchError, switchMap, throwError } from 'rxjs';
import { AuthService } from './auth.service';

/** Rotas que emitem a sessão: nunca levam Bearer, e um 401 delas é resposta, não sessão vencida. */
const SESSION_ROUTES = /\/auth\/(login|signup|refresh)$/;

function withBearer(req: HttpRequest<unknown>, token: string): HttpRequest<unknown> {
  return req.clone({ setHeaders: { Authorization: `Bearer ${token}` } });
}

function errorCode(error: HttpErrorResponse): string | undefined {
  return (error.error as { error?: { code?: string } } | null)?.error?.code;
}

/**
 * Anexa o Bearer nas rotas protegidas. Em 401 {@code TOKEN_EXPIRED} renova a sessão com o refresh
 * token (um refresh só, mesmo com várias requisições falhando juntas) e repete a requisição; se o
 * refresh falhar, ou o 401 for outro (sessão encerrada por troca de senha), volta ao login.
 */
export const authInterceptor: HttpInterceptorFn = (req, next) => {
  if (SESSION_ROUTES.test(req.url.split('?')[0])) {
    return next(req);
  }

  const auth = inject(AuthService);
  const router = inject(Router);
  const token = auth.token();

  const expire = (error: unknown) => {
    if (auth.expire()) {
      router.navigate(['/login']);
    }
    return throwError(() => error);
  };

  // A repetição não tenta outro refresh: se ainda for 401, a sessão acabou.
  const retry = (fresh: string) =>
    next(withBearer(req, fresh)).pipe(
      catchError((error: HttpErrorResponse) =>
        error.status === 401 ? expire(error) : throwError(() => error),
      ),
    );

  return next(token ? withBearer(req, token) : req).pipe(
    catchError((error: HttpErrorResponse) => {
      if (error.status !== 401 || !token) {
        return throwError(() => error);
      }
      if (errorCode(error) !== 'TOKEN_EXPIRED') {
        return expire(error);
      }
      const current = auth.token();
      if (current && current !== token) {
        // Outra requisição já renovou a sessão enquanto esta voltava com 401.
        return retry(current);
      }
      return auth.refresh().pipe(
        catchError(() => expire(error)),
        switchMap((fresh) => retry(fresh)),
      );
    }),
  );
};
