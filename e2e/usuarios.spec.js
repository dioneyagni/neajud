// Etapa 0.5 (3/4): the dono adds a worker with a função + an extra access and a
// provisional password; the worker must choose their own password, then sees
// only what the função allows; deactivated, they can't sign in any more.
const { E2E_USUARIO, entrar } = require("./support/sessao");
const { BASE_URL, runSpec } = require("./support/runner");
const { waitForText } = require("./support/wait");

runSpec("Usuários E2E Tests", async ({ page, test }) => {
  const joao = { nome: `João ${Date.now()}`, email: `joao${Date.now()}@neajud.test`, provisoria: "provisoria-e2e-1", senha: "senha-joao-e2e-1" };
  const linha = () => page.locator(`tr.usuario-linha[data-email="${joao.email}"]`);

  async function sair() {
    await page.click('.header-user button:has-text("Sign out")');
    await page.waitForURL("**/session/new");
  }

  async function entrarComo(email, senha) {
    await page.fill('input[name="email_address"]', email);
    await page.fill('input[name="password"]', senha);
    await page.click('input[type="submit"][value="Sign in"]');
  }

  async function navLinks() {
    return (await page.locator(".header-nav a").allTextContents()).map((t) => t.replace(/\s+/g, " ").trim());
  }

  await test("The dono opens Usuários and sees themselves as Dono, without Deactivate", async () => {
    await page.click('.header-nav a:has-text("Usuários")');
    await page.waitForURL("**/usuarios");
    const eu = page.locator(`tr.usuario-linha[data-email="${E2E_USUARIO.email}"]`);
    if (!(await eu.textContent()).includes("Dono")) throw new Error("Dono row doesn't show the Dono função");
    if ((await eu.locator('button:has-text("Deactivate")').count()) !== 0) throw new Error("The dono can deactivate themselves");
  });

  await test("Adding a user with função, an extra access and a provisional password", async () => {
    await page.click('a:has-text("+ New user")');
    await page.fill('input[name="usuario[nome]"]', joao.nome);
    await page.fill('input[name="usuario[email_address]"]', joao.email);
    await page.fill('input[name="usuario[senha_provisoria]"]', joao.provisoria);
    await page.selectOption('select[name="usuario[funcao_uuid]"]', { label: "Produção" });
    await page.selectOption('select[name="usuario[acessos_extras][niveis][pedidos]"]', { label: "Editar" });
    await page.click('input[type="submit"][value="Add user"]');
    await waitForText(page, `${joao.nome} added`);
    const texto = await linha().textContent();
    for (const esperado of ["Produção", "Pedidos: Editar", "provisional password", "active"]) {
      if (!texto.includes(esperado)) throw new Error(`Row lacks "${esperado}": ${texto.replace(/\s+/g, " ")}`);
    }
  });

  await test("With the provisional password, nothing opens until they choose their own", async () => {
    await sair();
    await entrarComo(joao.email, joao.provisoria);
    await page.waitForURL("**/senha/edit");
    await page.goto(`${BASE_URL}/pedidos`);
    await page.waitForURL("**/senha/edit");
    await page.fill('input[name="nova_senha"]', joao.senha);
    await page.click('input[type="submit"][value="Change password"]');
    await waitForText(page, "Password changed.");
  });

  // Produção: pedidos ver (+ extra editar), artes/catálogo/estoque ver, no clientes/lixeira/usuários.
  await test("The worker sees only what the função and the extra allow", async () => {
    const links = await navLinks();
    for (const visivel of ["Modelos", "Materials"]) if (!links.includes(visivel)) throw new Error(`Menu lacks ${visivel}: ${links}`);
    if (!links.some((l) => l.startsWith("Pedidos"))) throw new Error(`Menu lacks Pedidos: ${links}`);
    for (const oculto of ["Clients", "Lixeira", "Usuários", "Funções"]) if (links.includes(oculto)) throw new Error(`Menu shows ${oculto}: ${links}`);
    if ((await page.locator('h3:has-text("Upload New File")').count()) !== 0) throw new Error("Gallery upload shown to a read-only worker");
    await page.goto(`${BASE_URL}/pedidos`);
    if ((await page.locator('button:has-text("+ Novo Pedido")').count()) !== 1) throw new Error("The extra Pedidos: Editar didn't show + Novo Pedido");
  });

  await test("Pages outside the função answer Sem permissão", async () => {
    await page.goto(`${BASE_URL}/clients`);
    await waitForText(page, "Sem permissão");
    await page.goto(`${BASE_URL}/funcoes`);
    await waitForText(page, "Sem permissão");
  });

  await test("Deactivated by the dono, the worker can't sign in", async () => {
    await sair();
    await entrar(page, BASE_URL);
    await page.goto(`${BASE_URL}/usuarios`);
    await linha().locator('button:has-text("Deactivate")').click();
    await waitForText(page, `${joao.nome} deactivated`);
    if (!(await linha().textContent()).includes("deactivated")) throw new Error("Row doesn't show deactivated");
    await sair();
    await entrarComo(joao.email, joao.senha);
    await waitForText(page, "This account is deactivated");
  });
});
