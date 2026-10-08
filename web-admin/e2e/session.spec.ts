import { expect, test } from '@playwright/test';

const CUIDADORA = { email: 'ana@aura.com', senha: 'aura1234' };

/** JWT bem formado mas que o servidor recusa (assinatura que não é dele, vencido em 2020). */
const TOKEN_VELHO =
  'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIwMDAwMDAwMC0wMDAwLTAwMDAtMDAwMC0wMDAwMDAwMDAwMDAiLCJ0eXAiOiJhY2Nlc3MiLCJleHAiOjE1Nzc4MzY4MDB9.assinatura-invalida';

test.describe('sessão do painel', () => {
  test('token velho esquecido no navegador não atrapalha o login: entra de primeira', async ({
    page,
  }) => {
    await page.goto('/login');
    await page.evaluate((token) => {
      localStorage.setItem('aura.token', token);
      localStorage.setItem('aura.role', 'cuidadora');
      localStorage.setItem('aura.refreshToken', token);
    }, TOKEN_VELHO);

    await page.goto('/login');
    await page.fill('#email', CUIDADORA.email);
    await page.fill('#password', CUIDADORA.senha);
    await page.click('button[type="submit"]');

    await expect(page).toHaveURL(/\/home/);
    await expect(page.locator('.login .error')).toHaveCount(0);
    expect(await page.evaluate(() => localStorage.getItem('aura.refreshToken'))).not.toBe(
      TOKEN_VELHO,
    );
  });

  test('sessão recusada numa rota protegida volta ao login com o aviso, uma vez', async ({
    page,
  }) => {
    await page.goto('/login');
    await page.evaluate((token) => {
      localStorage.setItem('aura.token', token);
      localStorage.setItem('aura.role', 'cuidadora');
    }, TOKEN_VELHO);

    await page.goto('/home');
    await expect(page).toHaveURL(/\/login/);
    await expect(page.locator('.notice')).toHaveText('Sua sessão expirou. Entre novamente.');
    expect(await page.evaluate(() => localStorage.getItem('aura.token'))).toBeNull();

    await page.reload();
    await expect(page.locator('.notice')).toHaveCount(0);
  });
});
