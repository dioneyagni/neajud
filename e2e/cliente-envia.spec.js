// Etapa 2.8 (4b, decided 12/10/2026): a cliente final uploads his artes. With
// the default "Cliente final" (artes: editar) he sends a file from the
// gallery: it is his client's — it stays in his gallery after the reload,
// where a file without client would vanish — and he adds another file to that
// arte from its page. Versions and the client stay the team's.
const fs = require("fs");
const os = require("os");
const path = require("path");
const { BASE_URL, runSpec } = require("./support/runner");
const { testImagePath, ensureTestImage } = require("./support/fixtures");
const { uploadFileAndWait } = require("./support/upload");
const { waitForText } = require("./support/wait");

runSpec("Cliente envia E2E Tests", async ({ page, test }) => {
  const U = Date.now();
  const nomes = { cliente: `Cliente Envia ${U}`, arte: `envia-${U}`, outro: `envia-lingua-${U}` };
  const ivo = { email: `ivo${U}@neajud.test`, provisoria: "provisoria-ivo-1", senha: "senha-ivo-e2e-1" };
  const ids = {};
  const pasta = fs.mkdtempSync(path.join(os.tmpdir(), "cliente-envia-"));

  function copia(nome) {
    const destino = path.join(pasta, `${nome}.tif`);
    fs.copyFileSync(testImagePath, destino);
    return destino;
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
    await secao.locator("#acesso_nome").fill(`Ivo ${U}`);
    await secao.locator("#acesso_email").fill(ivo.email);
    await secao.locator("#acesso_senha").fill(ivo.provisoria);
    await secao.locator('input[type="submit"][value="Add access"]').click();
    await page.locator(`#acesso-ao-sistema tr.usuario-linha[data-email="${ivo.email}"]`).waitFor({ timeout: 10000 });
    await page.click('.header-user button:has-text("Sign out")');
    await page.waitForURL("**/session/new");
  });

  await test("The cliente final uploads an arte from the gallery: it is his client's", async () => {
    await page.fill('input[name="email_address"]', ivo.email);
    await page.fill('input[name="password"]', ivo.provisoria);
    await page.click('input[type="submit"][value="Sign in"]');
    await page.waitForURL("**/senha/edit");
    await page.fill('input[name="nova_senha"]', ivo.senha);
    await page.click('input[type="submit"][value="Change password"]');
    await page.waitForURL(/\/pedidos$/);
    await page.goto(`${BASE_URL}/arquivos`);
    await uploadFileAndWait(page, copia(nomes.arte));
    // The gallery reloaded: only his client's files are listed (Visibilidade).
    const cartao = page.locator(".stamp-card").filter({ hasText: nomes.arte });
    await cartao.waitFor({ timeout: 5000 });
    ids.arte = (await cartao.getAttribute("id")).replace(/^arquivo_/, "");
    await page.goto(`${BASE_URL}/arquivos/${ids.arte}`);
    if (!(await page.locator("#client-field-section .client-name-display").innerText()).includes(nomes.cliente)) throw new Error("The arte isn't his client's");
  });

  await test("Versions and the client are the team's: he gets neither control", async () => {
    // A new version in use, or another client, would change what the factory produces.
    if (await page.locator('h3:has-text("Upload New Version")').count()) throw new Error("The client gets Upload New Version");
    if (await page.locator('#client-field-section [title="Edit client"]').count()) throw new Error("The client can change the arte's client");
  });

  await test("He adds another file to his arte from its page", async () => {
    await page.locator(".arte-acrescentar summary").click();
    await page.setInputFiles(".arte-acrescentar-form input[type=file]", copia(nomes.outro));
    await page.fill('.arte-acrescentar-form input[name="tamanho_rotulo"]', "33-34");
    await page.locator('.arte-acrescentar-form button[type="submit"]').click();
    await waitForText(page, `${nomes.outro} added to this arte`);
    if (!(await page.locator("#arte-arquivos").innerText()).includes(nomes.outro)) throw new Error("The new file isn't listed in the arte");
  });

  await test("Cleanup", async () => {
    fs.rmSync(pasta, { recursive: true, force: true });
  });
});
