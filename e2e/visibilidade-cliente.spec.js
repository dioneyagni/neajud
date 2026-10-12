// Etapa 2.8 (3a, decided 10/10/2026): what a cliente final sees, by kind.
// The dono closes Moldes in the default grid (/visibilidade): the client's
// menu loses Moldes and the molde answers 404. An exception on the client's
// page opens Moldes and Valores for this client only: he sees the molde again,
// with its price per pair. The grid is put back at the end (shared database).
const { entrar } = require("./support/sessao");
const { BASE_URL, runSpec } = require("./support/runner");
const { modeloOficial, precificarMolde } = require("./support/catalogo");
const { waitForText } = require("./support/wait");

runSpec("Visibilidade para o cliente E2E Tests", async ({ page, test }) => {
  const U = Date.now();
  const nomes = { cliente: `Cliente Visível ${U}`, molde: `Visivel ${U}` };
  const caio = { nome: `Caio ${U}`, email: `caio${U}@neajud.test`, provisoria: "provisoria-caio-1", senha: "senha-caio-e2e-1" };
  const ids = {};

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

  async function entrarComoCaio(senha) {
    await sair();
    await page.fill('input[name="email_address"]', caio.email);
    await page.fill('input[name="password"]', senha);
    await page.click('input[type="submit"][value="Sign in"]');
  }

  async function voltarComoDono() {
    // A 404 page has no header: back to one that does.
    await page.goto(`${BASE_URL}/pedidos`);
    await sair();
    await entrar(page, BASE_URL);
  }

  async function menu() {
    return (await page.locator(".header-nav a").allTextContents()).map((t) => t.replace(/\s+/g, " ").trim());
  }

  async function grade(tipo, aberto) {
    await page.goto(`${BASE_URL}/visibilidade/edit`);
    await page.locator(`tr[data-tipo="${tipo}"] input[value="${aberto ? 1 : 0}"]`).check();
    await page.click('#visibilidade-padrao button[type="submit"]');
    await waitForText(page, "Default visibility saved.");
  }

  await test("Setup: a client with a priced molde and an access", async () => {
    await page.goto(BASE_URL);
    const tenis = await modeloOficial(page, "Tenis");
    await post("/clients", { "client[name]": nomes.cliente, "client[responsible]": "T" });
    ids.cliente = await buscar(`/clients/search?q=${encodeURIComponent(nomes.cliente)}`, "name", nomes.cliente);
    await post("/moldes", { "molde[sufixo]": nomes.molde, "molde[client_uuid]": ids.cliente, "molde[modelo_uuid]": tenis.id });
    ids.molde = await buscar(`/moldes/search?q=${encodeURIComponent(nomes.molde)}`, "sufixo", nomes.molde);
    if (!ids.molde) throw new Error(`Molde ${nomes.molde} wasn't created`);
    await precificarMolde(page, ids.molde, { preco: "12.5" });
    await page.goto(`${BASE_URL}/clients/${ids.cliente}`);
    const secao = page.locator("#acesso-ao-sistema");
    await secao.locator("#acesso_nome").fill(caio.nome);
    await secao.locator("#acesso_email").fill(caio.email);
    await secao.locator("#acesso_senha").fill(caio.provisoria);
    await secao.locator('input[type="submit"][value="Add access"]').click();
    await page.locator(`#acesso-ao-sistema tr.usuario-linha[data-email="${caio.email}"]`).waitFor({ timeout: 10000 });
  });

  await test("The dono closes Moldes in the default grid", async () => {
    await grade("moldes", false);
    if (!(await page.locator('tr[data-tipo="moldes"] input[value="0"]').isChecked())) throw new Error("Moldes isn't saved as closed");
    // The six kinds, and the arte previews are not one of them (always shown).
    if ((await page.locator("tr[data-tipo]").count()) !== 6) throw new Error("The grid doesn't list six kinds");
  });

  await test("With Moldes closed the cliente final has no Moldes and the molde is a 404", async () => {
    await entrarComoCaio(caio.provisoria);
    await page.waitForURL("**/senha/edit");
    await page.fill('input[name="nova_senha"]', caio.senha);
    await page.click('input[type="submit"][value="Change password"]');
    await page.waitForURL(/\/pedidos$/);
    if ((await menu()).includes("Moldes")) throw new Error(`Menu shows Moldes: ${await menu()}`);
    const resposta = await page.goto(`${BASE_URL}/moldes/${ids.molde}`);
    if (resposta.status() !== 404) throw new Error(`His closed molde answered ${resposta.status()}, expected 404`);
  });

  await test("An exception on the client's page opens Moldes and Valores for him", async () => {
    await voltarComoDono();
    await page.goto(`${BASE_URL}/clients/${ids.cliente}`);
    const secao = page.locator("#visibilidade");
    if ((await secao.locator('tr[data-tipo="moldes"] option:checked').textContent()).trim() !== "Default (closed)") throw new Error("Moldes doesn't follow the closed default");
    await secao.locator('tr[data-tipo="moldes"] select').selectOption("1");
    await secao.locator('tr[data-tipo="valores"] select').selectOption("1");
    await secao.locator('button:has-text("Save visibility")').click();
    await waitForText(page, `${nomes.cliente}'s visibility saved.`);
    if ((await page.locator('#visibilidade tr[data-tipo="valores"] option:checked').textContent()).trim() !== "Open") throw new Error("Valores isn't saved as open");
  });

  await test("He sees his molde again, with the price per pair and no cost", async () => {
    await entrarComoCaio(caio.senha);
    await page.waitForURL(/\/pedidos$/);
    if (!(await menu()).includes("Moldes")) throw new Error(`Menu lacks Moldes: ${await menu()}`);
    await page.goto(`${BASE_URL}/moldes/${ids.molde}`);
    const precos = page.locator("#molde-precos");
    await precos.waitFor({ timeout: 5000 });
    if (!(await precos.innerText()).includes("R$ 12,50")) throw new Error(`Price not shown: ${await precos.innerText()}`);
    // A client never edits the price, nor sees what it costs.
    if ((await precos.locator("form").count()) !== 0) throw new Error("The cliente final gets the price forms");
    if ((await page.locator("main").innerText()).includes("Custo")) throw new Error("A cost shows to the cliente final");
  });

  await test("Cleanup: the default grid opens Moldes again", async () => {
    await voltarComoDono();
    await grade("moldes", true);
  });
});
