import { expect, test, type Page } from '@playwright/test';

/**
 * O painel também é aberto no celular. A 390 px (iPhone 12/13/14) nenhuma rota pode rolar a
 * PÁGINA na horizontal: tabela larga rola dentro do próprio card, o resto quebra em coluna.
 * E os controles principais precisam de alvo de toque de pelo menos 44 px.
 */
test.use({ viewport: { width: 390, height: 844 }, hasTouch: true, isMobile: true });

const ADMIN = { email: 'admin@aura.com', senha: 'aura1234' };
const CUIDADORA = { email: 'ana@aura.com', senha: 'aura1234' };

async function entrar(page: Page, conta: { email: string; senha: string }) {
  await page.goto('/login');
  await page.fill('#email', conta.email);
  await page.fill('#password', conta.senha);
  await page.click('button[type="submit"]');
  await expect(page).not.toHaveURL(/\/login/);
}

async function overflowHorizontal(page: Page): Promise<number> {
  return page.evaluate(
    () => document.documentElement.scrollWidth - document.documentElement.clientWidth,
  );
}

/** Controles com caixa menor que 44 px em alguma dimensão (ignora os invisíveis). */
async function alvosPequenos(page: Page, seletor: string): Promise<string[]> {
  return page.locator(seletor).evaluateAll((els) =>
    els
      .map((el) => {
        // checkbox conta pelo rótulo que o envolve: tocar no texto marca a caixa
        const alvo = el.matches('input[type="checkbox"]') ? (el.closest('label') ?? el) : el;
        const r = alvo.getBoundingClientRect();
        return { r, nome: (alvo.textContent || el.getAttribute('name') || el.tagName).trim() };
      })
      .filter(({ r }) => r.width > 0 && r.height > 0 && (r.width < 44 || r.height < 44))
      .map(({ r, nome }) => `${nome} (${Math.round(r.width)}x${Math.round(r.height)})`),
  );
}

const CONTROLES =
  'main button, main a.btn, main input[type="checkbox"], main select, .topbar a, .topbar button';

async function esperarCarregar(page: Page) {
  await page.waitForLoadState('networkidle');
}

test('login cabe na largura do celular e os chips de demonstração são tocáveis', async ({
  page,
}) => {
  await page.goto('/login');
  await esperarCarregar(page);
  expect(await overflowHorizontal(page)).toBeLessThanOrEqual(0);
  expect(await alvosPequenos(page, CONTROLES)).toEqual([]);
});

test('nenhuma rota rola a página na horizontal a 390 px (admin)', async ({ page }) => {
  await entrar(page, ADMIN);
  for (const rota of ['/home', '/admin', '/parceiros']) {
    await page.goto(rota);
    await esperarCarregar(page);
    expect(await overflowHorizontal(page), `overflow em ${rota}`).toBeLessThanOrEqual(0);
    expect(await alvosPequenos(page, CONTROLES), `alvos pequenos em ${rota}`).toEqual([]);
  }

  // o catálogo continua uma tabela: quem rola é o card, nunca a página
  await page.goto('/admin');
  await expect(
    page.locator('.card', { hasText: 'Catálogo' }).locator('table tbody tr').first(),
  ).toBeVisible();
  expect(await overflowHorizontal(page)).toBeLessThanOrEqual(0);
});

test('a casa da cuidadora, com tabelas e checklist, cabe a 390 px', async ({ page }) => {
  await entrar(page, CUIDADORA);
  await page.goto('/home');
  // só lê: nada aqui grava, para não mexer no estado que o care-chain.spec espera
  await expect(page.locator('.check').first()).toBeVisible();
  await esperarCarregar(page);
  expect(await overflowHorizontal(page)).toBeLessThanOrEqual(0);
  expect(await alvosPequenos(page, CONTROLES)).toEqual([]);
});
