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

    // no card do Care-Chain — o card de reposição também usa .rec e vem antes no DOM
    const recomendacao = page.locator('.card', { hasText: 'Care-Chain' }).locator('.rec').first();
    await expect(recomendacao).toContainText('Barras de Apoio');
    // com escore na mesa o motivo sai composto: "porque houve <fatores> (norma)"
    await expect(recomendacao).toContainText('porque houve');
    await expect(recomendacao.locator('.tag')).toHaveText('Recomendado');

    // a decisão de compra mostra o custo completo: item + instalação = total
    await expect(recomendacao).toContainText('129,90');
    await expect(recomendacao).toContainText('279,80');

    const pedidosAntes = await page.locator('.order').count();

    await recomendacao.getByRole('button', { name: 'Aprovar e pedir' }).click();
    await expect(page.locator('.notice')).toContainText('cadeia logística');
    await expect(page.locator('.order')).toHaveCount(pedidosAntes + 1);
  });

  test('recusar uma recomendação não cria pedido', async ({ page }) => {
    await entrar(page, CUIDADORA);
    await page.getByRole('button', { name: 'Atualizar leituras' }).click();
    await expect(page.locator('.score').first()).toBeVisible();

    await page.getByRole('button', { name: 'Gerar recomendação' }).first().click();
    const careChain = page.locator('.card', { hasText: 'Care-Chain' });
    const recomendacao = careChain.locator('.rec').first();
    await expect(recomendacao.locator('.tag')).toHaveText('Recomendado');

    const pedidosAntes = await page.locator('.order').count();

    // RN-022 pelo navegador: a recusa é registrada e nenhum pedido nasce dela
    await recomendacao.getByRole('button', { name: 'Recusar' }).click();
    await expect(page.locator('.notice')).toContainText('Nenhum pedido');
    await expect(careChain.locator('.rec').first().locator('.tag')).toHaveText('Recusado');
    await expect(page.locator('.order')).toHaveCount(pedidosAntes);
  });

  test('a reposição por consumo nasce do burn rate e entra na mesma esteira', async ({ page }) => {
    await entrar(page, CUIDADORA);

    const card = page.locator('.card', { hasText: 'Reposição por consumo' });
    await expect(card).toBeVisible();
    await expect(card).toContainText('cerca de 5 dias');
    await expect(card).toContainText('média simples');
    await expect(card).toContainText('rede parceira');

    const pedidosAntes = await page.locator('.order').count();

    await card.getByRole('button', { name: 'Aprovar reposição' }).click();
    await expect(page.locator('.notice')).toContainText('cadeia logística');
    await expect(page.locator('.order')).toHaveCount(pedidosAntes + 1);
    await expect(page.locator('.order').first()).toContainText('refil');
  });

  test('o pedido avança pelos estágios da cadeia', async ({ page }) => {
    await entrar(page, CUIDADORA);
    const pedido = page.locator('.order').first();
    await expect(pedido).toBeVisible();

    const estagioAtual = pedido.locator('.timeline li.current');
    const antes = await estagioAtual.innerText();

    await pedido.getByRole('button', { name: 'Avançar estágio' }).click();
    await expect(page.locator('.notice')).toContainText('avançou');
    await expect(page.locator('.order').first().locator('.timeline li.current')).not.toHaveText(antes);
  });

  test('a última milha aparece no mapa com o entregador em rota', async ({ page }) => {
    await entrar(page, CUIDADORA);

    // pelo estágio, nunca pelo primeiro da lista: o teste de estágios muta o pedido mais recente
    const pedido = page
      .locator('.order', { has: page.locator('.timeline li.current', { hasText: 'Em rota' }) })
      .first();
    await expect(pedido).toBeVisible();

    await pedido.getByRole('button', { name: 'Ver entrega' }).click();
    await expect(pedido.locator('svg.map__svg')).toBeVisible();
    await expect(pedido.locator('.map__courier')).toBeVisible();

    const legenda = pedido.locator('.map__legend');
    await expect(legenda).toContainText('Saindo de: Loja Marginal');
    await expect(legenda).toContainText('km');
    await expect(legenda).toContainText('chega às');
  });
});

test.describe('torre de controle', () => {
  test('KPIs são exclusivos do admin', async ({ page }) => {
    await entrar(page, CUIDADORA);
    await page.click('a[href="/admin"]');
    // .empty também existe no catálogo enquanto a lista carrega — mirar só no aviso de KPIs
    await expect(page.locator('.empty').filter({ hasText: 'KPIs' })).toContainText('admin');
    await expect(page.locator('.kpis')).toHaveCount(0);

    await page.getByRole('button', { name: 'Sair' }).click();
    await entrar(page, ADMIN);
    await expect(page).toHaveURL(/\/admin/);

    await expect(page.locator('.kpis')).toBeVisible();
    await expect(page.locator('.kpi').first()).toContainText('OTIF');
    await expect(page.locator('.stage')).toHaveCount(6);

    // a carteira mostra os pedidos da operação, com estágio traduzido e situação de SLA
    const carteira = page.locator('.carteira');
    await expect(carteira).toContainText('Carteira de pedidos');
    await expect(carteira.locator('tbody tr').first()).toBeVisible();
    await expect(carteira).toContainText('Em rota');
    await expect(carteira).toContainText('SLA estourado');
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
    // a Torre agora tem duas tabelas: mirar na do catálogo
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
