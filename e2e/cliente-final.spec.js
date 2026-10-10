// Etapa 2.8 (2/5, decided 10/10/2026): a client's own access. The dono
// creates it on the client's page ("Acesso ao sistema") with a função para
// clientes; the person signs in, lands on Pedidos, sees only that client's
// moldes (another client's answers 404) and none of the team's pages;
// deactivated from the client's page, they can't sign in any more.
const { entrar } = require("./support/sessao");
const { BASE_URL, runSpec } = require("./support/runner");
const { modeloOficial } = require("./support/catalogo");
const { waitForText } = require("./support/wait");

runSpec("Cliente final E2E Tests", async ({ page, test }) => {
  const U = Date.now();
  const nomes = { alfa: `Cliente Alfa ${U}`, beta: `Cliente Beta ${U}`, moldeAlfa: `Alfa ${U}`, moldeBeta: `Beta ${U}` };
  const bia = { nome: `Bia ${U}`, email: `bia${U}@neajud.test`, provisoria: "provisoria-bia-1", senha: "senha-bia-e2e-1" };
  const ids = {};
  const linha = () => page.locator(`#acesso-ao-sistema tr.usuario-linha[data-email="${bia.email}"]`);

  async function post(url, campos) {
    return page.evaluate(async ({ url, campos }) => {
      const token = document.querySelector('meta[name="csrf-token"]')?.content || "";
      return (await fetch(url, { method: "POST", body: new URLSearchParams({ authenticity_token: token, ...campos }) })).ok;
    }, { url, campos });
  }

  async function buscar(url, chave, valor) {
    return page.evaluate(async ({ url, chave, valor }) => (await (await fetch(url)).json()).find((r) => r[chave] === valor)?.id, { url, chave, valor });
  }

  async function sair() {
    await page.click('.header-user button:has-text("Sign out")');
    await page.waitForURL("**/session/new");
  }

  async function entrarComo(email, senha) {
    await page.fill('input[name="email_address"]', email);
    await page.fill('input[name="password"]', senha);
    await page.click('input[type="submit"][value="Sign in"]');
  }

  await test("Setup: two clients, each with a molde", async () => {
    await page.goto(BASE_URL);
    const tenis = await modeloOficial(page, "Tenis");
    for (const [cliente, molde] of [[nomes.alfa, nomes.moldeAlfa], [nomes.beta, nomes.moldeBeta]]) {
      await post("/clients", { "client[name]": cliente, "client[responsible]": "T" });
      const clienteUuid = await buscar(`/clients/search?q=${encodeURIComponent(cliente)}`, "name", cliente);
      await post("/moldes", { "molde[sufixo]": molde, "molde[client_uuid]": clienteUuid, "molde[modelo_uuid]": tenis.id });
      ids[cliente] = clienteUuid;
      ids[molde] = await buscar(`/moldes/search?q=${encodeURIComponent(molde)}`, "sufixo", molde);
      if (!ids[molde]) throw new Error(`Molde ${molde} wasn't created`);
    }
  });

  await test("Funções lists Cliente final as a função para clientes, without the lixeira", async () => {
    await page.goto(`${BASE_URL}/funcoes`);
    const cabecalho = page.locator('th.funcao-coluna--cliente[data-funcao="Cliente final"]');
    await cabecalho.waitFor({ timeout: 5000 });
    if (!(await cabecalho.textContent()).includes("para clientes")) throw new Error("Cliente final isn't marked para clientes");
    // The trash is the team's: a client's função has no select for it.
    const lixeira = page.locator('tr[data-area="lixeira"] td[data-funcao="Cliente final"]');
    if ((await lixeira.locator("select").count()) !== 0) throw new Error("A função para clientes offers the lixeira");
  });

  await test("The dono adds an access on the client's page", async () => {
    await page.goto(`${BASE_URL}/clients/${ids[nomes.alfa]}`);
    const secao = page.locator("#acesso-ao-sistema");
    await secao.getByText("Nobody of this client signs in yet").waitFor({ timeout: 5000 });
    await secao.locator("#acesso_nome").fill(bia.nome);
    await secao.locator("#acesso_email").fill(bia.email);
    await secao.locator("#acesso_senha").fill(bia.provisoria);
    if ((await secao.locator("#acesso_funcao option:checked").innerText()).trim() !== "Cliente final") throw new Error("Cliente final isn't the função offered");
    await secao.locator('input[type="submit"][value="Add access"]').click();
    await linha().waitFor({ timeout: 10000 });
    if (!new URL(page.url()).pathname.endsWith(`/clients/${ids[nomes.alfa]}`)) throw new Error(`Expected the client's page, got ${page.url()}`);
    const texto = await linha().innerText();
    for (const esperado of ["Cliente final", "provisional password", "active"]) {
      if (!texto.includes(esperado)) throw new Error(`Row lacks "${esperado}": ${texto}`);
    }
  });

  // Usuários is the team's page; a cliente final is listed on his client's.
  await test("Usuários doesn't list the client's access", async () => {
    await page.goto(`${BASE_URL}/usuarios`);
    await page.locator(".usuarios-tabela").waitFor();
    if ((await page.locator(`tr.usuario-linha[data-email="${bia.email}"]`).count()) !== 0) throw new Error("A cliente final shows on Usuários");
  });

  await test("The cliente final chooses a password and lands on his pedidos", async () => {
    await sair();
    await entrarComo(bia.email, bia.provisoria);
    await page.waitForURL("**/senha/edit");
    await page.fill('input[name="nova_senha"]', bia.senha);
    await page.click('input[type="submit"][value="Change password"]');
    await page.waitForURL(/\/pedidos$/);
    await sair();
    await entrarComo(bia.email, bia.senha);
    await page.waitForURL(/\/pedidos$/);
    const cliente = (await page.locator(".header-user-cliente").innerText()).trim();
    if (cliente !== nomes.alfa) throw new Error(`Header shows "${cliente}", expected "${nomes.alfa}"`);
  });

  await test("He sees only his client's moldes, and none of the team's pages", async () => {
    const links = (await page.locator(".header-nav a").allTextContents()).map((t) => t.replace(/\s+/g, " ").trim());
    for (const oculto of ["Lixeira", "Usuários", "Funções", "Parâmetros"]) if (links.includes(oculto)) throw new Error(`Menu shows ${oculto}: ${links}`);
    await page.goto(`${BASE_URL}/moldes`);
    await page.getByText(nomes.moldeAlfa).first().waitFor({ timeout: 5000 });
    // Another client's records never show (Visibilidade): not listed, and by uuid a 404.
    if ((await page.getByText(nomes.moldeBeta).count()) !== 0) throw new Error("Another client's molde is listed");
    const resposta = await page.goto(`${BASE_URL}/moldes/${ids[nomes.moldeBeta]}`);
    if (resposta.status() !== 404) throw new Error(`Another client's molde answered ${resposta.status()}, expected 404`);
  });

  await test("Deactivated from the client's page, he can't sign in", async () => {
    await page.goto(BASE_URL);
    await sair();
    await entrar(page, BASE_URL);
    await page.goto(`${BASE_URL}/clients/${ids[nomes.alfa]}`);
    await linha().locator('button:has-text("Deactivate")').click();
    await waitForText(page, `${bia.nome} deactivated`);
    if (!(await linha().innerText()).includes("deactivated")) throw new Error("Row doesn't show deactivated");
    await sair();
    await entrarComo(bia.email, bia.senha);
    await waitForText(page, "This account is deactivated");
    await entrar(page, BASE_URL);
  });
});
