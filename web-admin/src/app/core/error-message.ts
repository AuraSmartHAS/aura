import { HttpErrorResponse } from '@angular/common/http';

/** O backend responde sempre {"error": {"code", "message"}} — aqui vira texto de tela. */
export function errorMessage(error: unknown, fallback = 'Não foi possível concluir a operação.'): string {
  if (error instanceof HttpErrorResponse) {
    if (error.status === 0) {
      return 'Não conseguimos falar com o AURA agora. Espere um instante e recarregue a página.';
    }
    const body = error.error as { error?: { code?: string; message?: string } } | null;
    if (body?.error?.message) {
      return body.error.message;
    }
  }
  return fallback;
}
