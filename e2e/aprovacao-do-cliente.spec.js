// Etapa 2.8 (4a, decided 12/10/2026): the cliente final answers a request for
// approval in the system. The team sends an arte with two versions (v2 in
// use); the client approves v1 — "aprovada em outra versão" — and the team's
// "Usar esta versão" approves it. After a v3 sent again, the client asks for
// changes with a note, which the team reads on the arte's page.
const fs = require("fs");
const os = require("os");
const path = require("path");
const { entrar } = require("./support/sessao");
const { BASE_URL, runSpec } = require("./support/runner");
const { testImagePath, ensureTestImage } = require("./support/fixtures");
const { uploadFileAndWait, waitForUploadedProcessed } = require("./support/upload");
const { waitForText } = require("./support/wait");

runSpec("Aprovação do cliente E2E Tests", async ({ page, test }) => {
  const U = Date.now();
  const nomes = { cliente: `Cliente Aprova ${U}`, arte: `aprova-${U}` };
  const eva = { email: `eva${U}@neajud.test`, provisoria: "provisoria-eva-1", senha: "senha-eva-e2e-1" };
  const ids = {};
  const pasta = fs.mkdtempSync(path.join(os.tmpdir(), "aprovacao-do-cliente-"));

  async function enviar(url, campos) {
    return page.evaluate(async ({ url, campos }) => {
      const token = document.querySelector('meta[name="csrf-token"]')?.content || "";
      return (await fetch(url, { method: "POST", body: new URLSearchParams({ authenticity_token: token, ...campos }) })).ok;
    }, { url, campos });
  }

  // A new version, as the arte page's "Upload new version" sends it.
  async function novaVersao() {
    const bytes = Array.from(fs.readFileSync(testImagePath));
    const ok = await page.evaluate(async ({ url, bytes, nome }) => {
      const corpo = new FormData();
      corpo.append("authenticity_token", document.querySelector('meta[name="csrf-token"]')?.content || "");
      corpo.append("original_file", new File([new Uint8Array(bytes)], nome, { type: "image/tiff" }));
      return (await fetch(url, { method: "POST", body: corpo })).ok;
    }, { url: `/arquivos/${ids.arte}/upload_version`, bytes, nome: `${nomes.arte}.tif` });
    if (!ok) throw new Error("upload_version failed");
    await waitForUploadedProcessed(page, [ids.arte], [nomes.arte]);
  }

  async function sair() {
    await page.goto(`${BASE_URL}/pedidos`);
    await page.click('.header-user button:has-text("Sign out")');
    await page.waitForURL("**/session/new");
  }

  async function entrarComoEva(senha) {
    await sair();
    await page.fill('input[name="email_address"]', eva.email);
    await page.fill('input[name="password"]', senha);
    await page.click('input[type="submit"][value="Sign in"]');
  }

  async function voltarComoEquipe() {
    await sair();
    await entrar(page, BASE_URL);
  }

  async function abrirArte() {
    await page.goto(`${BASE_URL}/arquivos/${ids.arte}`);
    await page.locator("#aprovacao-section").waitFor({ timeout: 5000 });
  }

  async function estado() {
    return page.locator("#aprovacao-section").getAttribute("data-estado");
  }

  async function enviarParaAprovacao(botao) {
    await abrirArte();
    await page.locator(`#aprovacao-section button:has-text("${botao}")`).click();
    // The notice, not the history (which also says "sent for approval").
    await waitForText(page, "sent for approval (1 file).");
  }

  await test("Setup: the client's arte with v1 and v2, sent for approval, and his access", async () => {
    ensureTestImage();
    await page.goto(BASE_URL);
    await enviar("/clients", { "client[name]": nomes.cliente, "client[responsible]": "T" });
    ids.cliente = await page.evaluate(async (nome) => (await (await fetch(`/clients/search?q=${encodeURIComponent(nome)}`)).json()).find((c) => c.name === nome)?.id, nomes.cliente);
    const arquivo = path.join(pasta, `${nomes.arte}.tif`);
    fs.copyFileSync(testImagePath, arquivo);
    await uploadFileAndWait(page, arquivo);
    ids.arte = (await page.locator(".stamp-card").filter({ hasText: nomes.arte }).first().getAttribute("id")).replace(/^arquivo_/, "");
    if (!(await enviar(`/arquivos/${ids.arte}/update_client`, { _method: "patch", client_uuid: ids.cliente }))) throw new Error("Couldn't give the arte its client");
    await novaVersao();
    await enviarParaAprovacao("Send for approval");
    await page.goto(`${BASE_URL}/clients/${ids.cliente}`);
    const secao = page.locator("#acesso-ao-sistema");
    await secao.locator("#acesso_nome").fill(`Eva ${U}`);
    await secao.locator("#acesso_email").fill(eva.email);
    await secao.locator("#acesso_senha").fill(eva.provisoria);
    await secao.locator('input[type="submit"][value="Add access"]').click();
    await page.locator(`#acesso-ao-sistema tr.usuario-linha[data-email="${eva.email}"]`).waitFor({ timeout: 10000 });
  });

  await test("The cliente final picks v1 and approves: approved in another version", async () => {
    await entrarComoEva(eva.provisoria);
    await page.waitForURL("**/senha/edit");
    await page.fill('input[name="nova_senha"]', eva.senha);
    await page.click('input[type="submit"][value="Change password"]');
    await page.waitForURL(/\/pedidos$/);
    await abrirArte();
    // Sending and registering are the team's: he only answers.
    if (await page.locator('#aprovacao-section :text("Register approval")').count()) throw new Error("The client sees Register approval");
    const versao = page.locator(`#resposta-do-cliente select[name="versoes[${ids.arte}]"]`);
    const opcoes = (await versao.locator("option").allTextContents()).map((t) => t.trim());
    if (opcoes.join() !== "v2 (in use),v1") throw new Error(`Versions offered: ${opcoes}`);
    await versao.selectOption({ label: "v1" });
    await page.click('#resposta-do-cliente button:has-text("Approve")');
    await waitForText(page, "approved in other versions than the ones in use");
    if ((await estado()) !== "aprovada_em_outra_versao") throw new Error(`State is ${await estado()}`);
    await page.locator("#aprovacao-outra-versao").getByText("the factory will switch to it").waitFor({ timeout: 5000 });
  });

  await test("The team switches to v1 and the arte is approved in the system", async () => {
    await voltarComoEquipe();
    await abrirArte();
    const linha = page.locator("#aprovacao-outra-versao li");
    if (!(await linha.innerText()).includes("the client approved v1")) throw new Error(`Line: ${await linha.innerText()}`);
    await linha.locator('button:has-text("Usar esta versão")').click();
    await waitForText(page, "Version 1 is now in use.");
    if ((await estado()) !== "aprovada") throw new Error(`State is ${await estado()}`);
    if (!(await page.locator("#aprovacao-section .badge-aprovacao--aprovada").innerText()).includes("No sistema")) throw new Error("The approval doesn't say No sistema");
  });

  await test("A v3 sent again: the client asks for changes, the team reads the note", async () => {
    await novaVersao();
    await enviarParaAprovacao("Send for approval");
    await entrarComoEva(eva.senha);
    await page.waitForURL(/\/pedidos$/);
    await abrirArte();
    await page.fill("#resposta-do-cliente #recado", "Azul mais escuro, por favor");
    await page.click('#resposta-do-cliente button:has-text("Ask for changes")');
    await waitForText(page, "Changes asked for");
    if ((await estado()) !== "alteracao_pedida") throw new Error(`State is ${await estado()}`);

    await voltarComoEquipe();
    await abrirArte();
    if (!(await page.locator("#alteracao-pedida").innerText()).includes("Azul mais escuro, por favor")) throw new Error("The team doesn't see the note");
    await enviarParaAprovacao("Send for approval again");
    if ((await estado()) !== "aguardando") throw new Error(`State is ${await estado()}`);
  });

  await test("Cleanup", async () => {
    fs.rmSync(pasta, { recursive: true, force: true });
  });
});
