import { expect, test, type Page } from '@playwright/test';

const CUIDADORA = { email: 'ana@aura.com', senha: 'aura1234' };
const ADMIN = { email: 'admin@aura.com', senha: 'aura1234' };

async function entrar(page: Page, conta: { email: string; senha: string }) {
  await page.goto('/login');
  await page.fill('#email', conta.email);
  await page.fill('#password', conta.senha);
  await page.click('button[type="submit"]');
}

test.describe('painel da cuidadora', () => {
  test('o risco explicado reage ao checklist de segurança', async ({ page }) => {
    await entrar(page, CUIDADORA);
    await expect(page).toHaveURL(/\/home/);

    await page.getByRole('button', { name: 'Atualizar leituras' }).click();
    await expect(page.locator('.score').first()).toBeVisible();

    // o escore precisa mostrar POR QUE subiu — é a promessa do produto
    const explicacao = page.locator('.score .explain').first();
    await expect(explicacao).toContainText('NBR 9050');
    await expect(page.locator('.score .factors li').first()).not.toContainText('_');

    const antes = await page.locator('.score .badge').first().innerText();

    // alterna a barra de apoio: o fator "no_grab_bar" entra ou sai da conta
    const barra = page.locator('.check', { hasText: 'Barra de apoio no banheiro' }).locator('input');
    await barra.click();
    await page.getByRole('button', { name: 'Salvar checklist' }).click();
    await expect(page.locator('.notice')).toBeVisible();

    await page.getByRole('button', { name: 'Atualizar leituras' }).click();
    await expect(page.locator('.score .badge').first()).not.toHaveText(antes);

    // devolve o checklist ao estado anterior para o teste ser repetível
    await barra.click();
    await page.getByRole('button', { name: 'Salvar checklist' }).click();
  });

  test('nada é comprado sem a aprovação da cuidadora', async ({ page }) => {
    await entrar(page, CUIDADORA);
    await page.getByRole('button', { name: 'Atualizar leituras' }).click();
    await expect(page.locator('.score').first()).toBeVisible();

    const gerar = page.getByRole('button', { name: 'Gerar recomendação' }).first();
    await expect(gerar).toBeVisible();
    await gerar.click();

    // no card das recomendações — o card de reposição também usa .rec e vem antes no DOM
    const recomendacao = page.locator('.card', { hasText: 'O que a casa precisa' }).locator('.rec').first();
    await expect(recomendacao).toContainText('Barras de Apoio');
    // com escore na mesa o motivo sai composto: "porque houve <fatores> (norma)"
    await expect(recomendacao).toContainText('porque houve');
    await expect(recomendacao.locator('.tag')).toHaveText('Recomendado');

    // a decisão de compra mostra o custo completo: item + instalação = total
    await expect(recomendacao).toContainText('129,90');
    await expect(recomendacao).toContainText('279,80');

    // aprovar não compra nada aqui: a família segue para o site do parceiro (D-008)
    await recomendacao.getByRole('button', { name: 'Aprovar' }).click();
    await expect(page.locator('.notice')).toContainText('site do parceiro');
    const aprovada = page.locator('.card', { hasText: 'O que a casa precisa' }).locator('.rec', { hasText: 'Barras de Apoio' }).first();
    await expect(aprovada.locator('.tag')).toHaveText('Aprovado');
    await expect(aprovada.getByRole('link', { name: /Ver no site de/ })).toBeVisible();
  });

  test('recusar uma recomendação não cria pedido', async ({ page }) => {
    await entrar(page, CUIDADORA);
    await page.getByRole('button', { name: 'Atualizar leituras' }).click();
    await expect(page.locator('.score').first()).toBeVisible();

    await page.getByRole('button', { name: 'Gerar recomendação' }).first().click();
    const recomendacoes = page.locator('.card', { hasText: 'O que a casa precisa' });
    const recomendacao = recomendacoes.locator('.rec').first();
    await expect(recomendacao.locator('.tag')).toHaveText('Recomendado');

    // RN-022 pelo navegador: a recusa é registrada e nenhum pedido nasce dela
    await recomendacao.getByRole('button', { name: 'Recusar' }).click();
    await expect(page.locator('.notice')).toContainText('Nenhum pedido');
    await expect(recomendacoes.locator('.rec').first().locator('.tag')).toHaveText('Recusado');
  });

  test('a reposição por consumo nasce do burn rate e pede aprovação', async ({ page }) => {
    await entrar(page, CUIDADORA);

    const card = page.locator('.card', { hasText: 'Reposição por consumo' });
    await expect(card).toBeVisible();
    await expect(card).toContainText('acaba em uns');
    await expect(card).toContainText('média simples');
    await expect(card).toContainText('rede parceira');

    await card.getByRole('button', { name: 'Aprovar reposição' }).click();
    await expect(page.locator('.notice')).toContainText('site do parceiro');
    // a aprovação fica registrada entre as recomendações da casa
    const recomendacoes = page.locator('.card', { hasText: 'O que a casa precisa' });
    await expect(recomendacoes.locator('.rec', { hasText: /refil/i }).locator('.tag', { hasText: 'Aprovado' }).first()).toBeVisible();
    // Sem entrega própria (D-008) nada repõe o estoque depois da aprovação, então a régua volta
    // a sugerir na próxima leitura. Comportamento conhecido, à espera de decisão de produto.
  });

  test('fora do Oracle, avisos e consumo não fingem medição', async ({ page }) => {
    // A suíte e2e sobe o backend em H2: a inteligência mora no Oracle, então o backend
    // responde engine "indisponivel" e os cards somem em vez de mostrar zero.
    await entrar(page, CUIDADORA);
    await expect(page.locator('.score, .empty').first()).toBeVisible();
    await expect(page.getByRole('heading', { name: 'Avisos da casa' })).toHaveCount(0);
    await expect(page.getByRole('heading', { name: 'Consumo do período' })).toHaveCount(0);
  });
});

test.describe('operação', () => {
  test('indicadores são exclusivos do admin', async ({ page }) => {
    await entrar(page, CUIDADORA);
    await page.click('a[href="/admin"]');
    // .empty também existe no catálogo enquanto a lista carrega — mirar só no aviso de papel
    await expect(page.locator('.empty').filter({ hasText: 'exclusivos' })).toContainText('admin');
    await expect(page.locator('.kpis')).toHaveCount(0);

    await page.getByRole('button', { name: 'Sair' }).click();
    await entrar(page, ADMIN);
    await expect(page).toHaveURL(/\/admin/);

    await expect(page.locator('.kpis')).toBeVisible();
    await expect(page.locator('.kpi').first()).toContainText('Casas monitoradas');
    // a logística saiu (D-008): nada de carteira de pedidos nem métrica de frota na tela
    await expect(page.locator('.carteira')).toHaveCount(0);
    await expect(page.locator('body')).not.toContainText('OTIF');
  });

  test('admin administra o catálogo de acessibilidade', async ({ page }) => {
    await entrar(page, ADMIN);
    const sku = `QA-E2E-${Date.now()}`;

    await page.fill('#sku', sku);
    await page.fill('#name', 'Barra de apoio 90cm (teste e2e)');
    await page.fill('#category', 'Barra de apoio');
    await page.fill('#price', '119.90');
    await page.getByRole('button', { name: 'Cadastrar item' }).click();

    await expect(page.locator('.notice')).toContainText('cadastrado');
    await expect(page.locator('.card', { hasText: 'Catálogo' }).locator('table')).toContainText(sku);

    // limpa o que criou
    page.once('dialog', (d) => d.accept());
    await page.locator('tr', { hasText: sku }).getByRole('button', { name: 'Excluir' }).click();
    await expect(page.locator('.notice')).toContainText('removido');
  });
});

test('credenciais inválidas mostram o erro vindo da API', async ({ page }) => {
  await entrar(page, { email: 'ana@aura.com', senha: 'senha-errada' });
  await expect(page.locator('.error')).toContainText('incorret');
  await expect(page).toHaveURL(/\/login/);
});
