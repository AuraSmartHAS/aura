import { HttpErrorResponse } from '@angular/common/http';
import { errorMessage } from './error-message';

describe('errorMessage', () => {
  it('usa a mensagem do envelope da API', () => {
    const erro = new HttpErrorResponse({
      status: 422,
      error: { error: { code: 'CONSENT_REQUIRED', message: 'Aceite a Política antes de usar.' } },
    });

    expect(errorMessage(erro)).toBe('Aceite a Política antes de usar.');
  });

  it('explica o que fazer quando a API está fora do ar', () => {
    const erro = new HttpErrorResponse({ status: 0 });
    expect(errorMessage(erro)).toContain('Não conseguimos falar com o AURA');
  });

  it('cai no texto padrão quando o corpo não tem envelope', () => {
    const erro = new HttpErrorResponse({ status: 500, error: 'boom' });
    expect(errorMessage(erro, 'Falhou.')).toBe('Falhou.');
  });
});
