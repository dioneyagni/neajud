// Etapa 2.8 (5/5, decided 12/10/2026): a cliente final builds his draft and
// sends it to the factory — pendências never stop him; the factory's show as
// "em análise". He takes it back and sends again; the team sees it counted
// in the header, returns it with a note, which he reads on top of his
// Pedidos; sent again, the team gets "Confirmar pedido".
const fs = require("fs");
const os = require("os");
const path = require("path");
const { entrar } = require("./support/sessao");
const { BASE_URL, runSpec } = require("./support/runner");
const { testImagePath, ensureTestImage } = require("./support/fixtures");
const { uploadFileAndWait } = require("./support/upload");
const { waitForText } = require("./support/wait");

runSpec("Cliente rascunho E2E Tests", async ({ page, test }) => {
  const U = Date.now();
  const nomes = { cliente: `Cliente Rascunho ${U}`, arte: `rascunho-${U}` };
  const leo = { email: `leo${U}@neajud.test`, provisoria: "provisoria-leo-1", senha: "senha-leo-e2e-1" };
  const recado = "Falta a língua no 35";
  const ids = {};
  const pasta = fs.mkdtempSync(path.join(os.tmpdir(), "cliente-rascunho-"));

  async function sair() {
    await page.goto(`${BASE_URL}/pedidos`);
    await page.click('.header-user button:has-text("Sign out")');
    await page.waitForURL("**/session/new");
  }

  async function entrarComoLeo() {
    await sair();
    await page.fill('input[name="email_address"]', leo.email);
    await page.fill('input[name="password"]', leo.senha);
    await page.click('input[type="submit"][value="Sign in"]');
    await page.waitForURL(/\/pedidos$/);
  }

  async function abrirPedido() {
    await page.goto(`${BASE_URL}/pedidos/${ids.pedido}/resumo`);
    await page.locator(".pedido-painel").waitFor({ timeout: 5000 });
  }

  async function status() {
    return (await page.locator("h2 .badge").innerText()).trim();
  }

  await test("Setup: a client with an access", async () => {
    ensureTestImage();
    await page.goto(BASE_URL);
    const ok = await page.evaluate(async (nome) => {
      const token = document.querySelector('meta[name="csrf-token"]')?.content || "";
      return (await fetch("/clients", { method: "POST", body: new URLSearchParams({ authenticity_token: token, "client[name]": nome, "client[responsible]": "T" }) })).ok;
    }, nomes.cliente);
    if (!ok) throw new Error("Couldn't create the client");
    ids.cliente = await page.evaluate(async (nome) => (await (await fetch(`/clients/search?q=${encodeURIComponent(nome)}`)).json()).find((c) => c.name === nome)?.id, nomes.cliente);
    await page.goto(`${BASE_URL}/clients/${ids.cliente}`);
    const secao = page.locator("#acesso-ao-sistema");
    await secao.locator("#acesso_nome").fill(`Leo ${U}`);
    await secao.locator("#acesso_email").fill(leo.email);
    await secao.locator("#acesso_senha").fill(leo.provisoria);
    await secao.locator('input[type="submit"][value="Add access"]').click();
    await page.locator(`#acesso-ao-sistema tr.usuario-linha[data-email="${leo.email}"]`).waitFor({ timeout: 10000 });
  });

  await test("The cliente final adds his arte to a draft from the gallery", async () => {
    await sair();
    await page.fill('input[name="email_address"]', leo.email);
    await page.fill('input[name="password"]', leo.provisoria);
    await page.click('input[type="submit"][value="Sign in"]');
    await page.waitForURL("**/senha/edit");
    await page.fill('input[name="nova_senha"]', leo.senha);
    await page.click('input[type="submit"][value="Change password"]');
    await page.waitForURL(/\/pedidos$/);
    await page.goto(`${BASE_URL}/arquivos`);
    const arquivo = path.join(pasta, `${nomes.arte}.tif`);
    fs.copyFileSync(testImagePath, arquivo);
    await uploadFileAndWait(page, arquivo);
    await page.locator(".stamp-card").filter({ hasText: nomes.arte }).locator(".btn-add-to-order").click({ force: true });
    await page.locator(".add-to-order-dialog[open]").waitFor({ timeout: 5000 });
    await page.locator(".add-to-order-qtd-total, .add-to-order-grade-input").first().fill("2");
    const [resposta] = await Promise.all([
      page.waitForResponse((r) => r.url().includes("/pedidos/adicionar_item")),
      page.locator("[data-add-to-order-target='submitBtn']").click()
    ]);
    const corpo = await resposta.json();
    if (!corpo.ok) throw new Error(`adicionar_item: ${corpo.error}`);
    ids.pedido = corpo.pedido_uuid;
  });

  await test("He sends it with the factory's pendências shown as em análise", async () => {
    await abrirPedido();
    // No molde, no price per pair: the factory's to settle, never his.
    const pendencia = page.locator(".pedido-pendencia--sem_preco");
    if ((await pendencia.locator(".pedido-pendencia-em-analise").innerText()).trim() !== "em análise") throw new Error("sem_preco isn't em análise");
    // Confirming is the factory's.
    if (await page.locator(".pedido-confirmar").count()) throw new Error("The client gets Confirmar pedido");
    await page.locator(".pedido-enviar").click();
    await waitForText(page, "Pedido sent to the factory.");
    if ((await status()) !== "aguardando a fábrica") throw new Error(`Status is ${await status()}`);
    // Sent, the factory looks at it: he can't change it until he takes it back.
    if (await page.locator(".pedido-adicionar").count()) throw new Error("A sent pedido still takes artes from the client");
  });

  await test("He takes it back and sends it again", async () => {
    await page.locator(".pedido-retirar").click();
    await waitForText(page, "Pedido taken back");
    if ((await status()) !== "rascunho") throw new Error(`Status is ${await status()}`);
    await page.locator(".pedido-enviar").click();
    await waitForText(page, "Pedido sent to the factory.");
    const historico = await page.locator(".pedido-eventos").innerText();
    if (!historico.includes("Envio retirado pelo cliente")) throw new Error(`History: ${historico}`);
  });

  await test("The team sees it counted in the header and returns it with a note", async () => {
    await sair();
    await entrar(page, BASE_URL);
    await page.goto(`${BASE_URL}/pedidos`);
    await page.locator(".header-aguardando-fabrica").click();
    await page.waitForURL(/status=enviado/);
    await page.getByRole("link", { name: ids.pedido.slice(0, 8), exact: true }).waitFor({ timeout: 5000 });
    await abrirPedido();
    if (!(await page.locator(".pedido-confirmar").count())) throw new Error("The team has no Confirmar pedido on a sent pedido");
    await page.locator(".pedido-devolver summary").click();
    await page.fill("#pedido-devolver-recado", recado);
    await page.click('.pedido-devolver-form button[type="submit"]');
    await waitForText(page, "Pedido returned to the client.");
    if ((await status()) !== "rascunho") throw new Error(`Status is ${await status()}`);
  });

  await test("The client reads the note on top of his Pedidos and sends it again", async () => {
    await entrarComoLeo();
    const devolvido = page.locator(`.pedidos-devolvidos li[data-pedido="${ids.pedido}"]`);
    if ((await devolvido.locator("blockquote").innerText()).trim() !== recado) throw new Error("The note isn't on top of his Pedidos");
    await devolvido.locator("a").click();
    await page.locator("#pedido-devolvido").getByText(recado).waitFor({ timeout: 5000 });
    await page.locator(".pedido-enviar").click();
    await waitForText(page, "Pedido sent to the factory.");
    // Sent again, the note is no longer pending — only in the history.
    if (await page.locator("#pedido-devolvido").count()) throw new Error("The note still shows as pending");
  });

  await test("Cleanup", async () => {
    await sair();
    await entrar(page, BASE_URL);
    fs.rmSync(pasta, { recursive: true, force: true });
  });
});
