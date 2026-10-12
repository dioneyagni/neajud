// Etapa 2.8 (3b, decided 11/10/2026): live updates per client. The gallery's
// cards went to one cable stream for everyone, so a cliente final received
// every client's cards over the WebSocket (not shown, but readable in the
// browser's tools). Now each card goes to the team and to the clients that see
// it, through AoVivoChannel, which checks who subscribes.
//
// The team (this page) and a cliente final (a second browser context) side by
// side: the team uploads a new version of a file without client, then of the
// client's arte; the client's gallery swaps his card without a reload and
// never receives the other one over the cable.
const fs = require("fs");
const os = require("os");
const path = require("path");
const { BASE_URL, runSpec } = require("./support/runner");
const { testImagePath, ensureTestImage } = require("./support/fixtures");
const { uploadFileAndWait, waitForUploadedProcessed } = require("./support/upload");

runSpec("Canais ao vivo E2E Tests", async ({ page, test }) => {
  const U = Date.now();
  const nomes = { cliente: `Cliente Ao Vivo ${U}`, dele: `canal-dele-${U}`, alheio: `canal-alheio-${U}` };
  const dani = { email: `dani${U}@neajud.test`, provisoria: "provisoria-dani-1", senha: "senha-dani-e2e-1" };
  const ids = {};
  const pasta = fs.mkdtempSync(path.join(os.tmpdir(), "canais-ao-vivo-"));
  let contexto;
  let cliente;
  const recebidos = [];

  async function enviar(url, campos) {
    return page.evaluate(async ({ url, campos }) => {
      const token = document.querySelector('meta[name="csrf-token"]')?.content || "";
      return (await fetch(url, { method: "POST", body: new URLSearchParams({ authenticity_token: token, ...campos }) })).ok;
    }, { url, campos });
  }

  // A new version of the file through upload_version, as the arte page sends it.
  async function novaVersao(uuid, nome) {
    const bytes = Array.from(fs.readFileSync(testImagePath));
    const ok = await page.evaluate(async ({ url, bytes, nome }) => {
      const corpo = new FormData();
      corpo.append("authenticity_token", document.querySelector('meta[name="csrf-token"]')?.content || "");
      corpo.append("original_file", new File([new Uint8Array(bytes)], nome, { type: "image/tiff" }));
      return (await fetch(url, { method: "POST", body: corpo })).ok;
    }, { url: `/arquivos/${uuid}/upload_version`, bytes, nome: `${nome}.tif` });
    if (!ok) throw new Error(`upload_version of ${nome} failed`);
  }

  async function subir(nome) {
    const arquivo = path.join(pasta, `${nome}.tif`);
    fs.copyFileSync(testImagePath, arquivo);
    await page.goto(BASE_URL);
    await uploadFileAndWait(page, arquivo);
    const id = await page.locator(".stamp-card").filter({ hasText: nome }).first().getAttribute("id");
    return id.replace(/^arquivo_/, "");
  }

  await test("Setup: a client with an access, his arte and a file of nobody's", async () => {
    ensureTestImage();
    await page.goto(BASE_URL);
    await enviar("/clients", { "client[name]": nomes.cliente, "client[responsible]": "T" });
    ids.cliente = await page.evaluate(async (nome) => (await (await fetch(`/clients/search?q=${encodeURIComponent(nome)}`)).json()).find((c) => c.name === nome)?.id, nomes.cliente);
    ids.dele = await subir(nomes.dele);
    ids.alheio = await subir(nomes.alheio);
    if (!(await enviar(`/arquivos/${ids.dele}/update_client`, { _method: "patch", client_uuid: ids.cliente }))) throw new Error("Couldn't give the arte its client");
    await page.goto(`${BASE_URL}/clients/${ids.cliente}`);
    const secao = page.locator("#acesso-ao-sistema");
    await secao.locator("#acesso_nome").fill(`Dani ${U}`);
    await secao.locator("#acesso_email").fill(dani.email);
    await secao.locator("#acesso_senha").fill(dani.provisoria);
    await secao.locator('input[type="submit"][value="Add access"]').click();
    await page.locator(`#acesso-ao-sistema tr.usuario-linha[data-email="${dani.email}"]`).waitFor({ timeout: 10000 });
  });

  await test("The cliente final's gallery listens to his client's stream only", async () => {
    contexto = await page.context().browser().newContext();
    cliente = await contexto.newPage();
    cliente.on("websocket", (ws) => ws.on("framereceived", (frame) => recebidos.push(String(frame.payload))));
    await cliente.goto(BASE_URL);
    await cliente.fill('input[name="email_address"]', dani.email);
    await cliente.fill('input[name="password"]', dani.provisoria);
    await cliente.click('input[type="submit"][value="Sign in"]');
    await cliente.waitForURL("**/senha/edit");
    await cliente.fill('input[name="nova_senha"]', dani.senha);
    await cliente.click('input[type="submit"][value="Change password"]');
    await cliente.waitForURL(/\/pedidos$/);
    await cliente.goto(`${BASE_URL}/arquivos`);
    await cliente.locator(`#arquivo_${ids.dele}`).waitFor({ timeout: 5000 });
    const canais = await cliente.locator("turbo-cable-stream-source").evaluateAll((fontes) => fontes.map((f) => f.getAttribute("channel")));
    if (canais.join() !== "AoVivoChannel") throw new Error(`Expected one AoVivoChannel stream, got ${canais}`);
    // Subscribed: Action Cable confirms each subscription with a frame.
    await cliente.waitForFunction(() => document.querySelector("turbo-cable-stream-source")?.hasAttribute("connected"), null, { timeout: 10000 });
  });

  await test("A new version of his arte swaps his card live; nobody's file never reaches him", async () => {
    await cliente.evaluate(() => { window.semRecarregar = true; });
    const antes = await cliente.locator(`#arquivo_${ids.dele} img`).first().getAttribute("src");
    // Nobody's file first: its broadcasts are out before his arte's arrive.
    await novaVersao(ids.alheio, nomes.alheio);
    await waitForUploadedProcessed(page, [ids.alheio], [nomes.alheio]);
    await novaVersao(ids.dele, nomes.dele);
    await waitForUploadedProcessed(page, [ids.dele], [nomes.dele]);
    await cliente.waitForFunction(({ id, antes }) => {
      const img = document.querySelector(`#arquivo_${id} img`);
      return img && img.getAttribute("src") !== antes && document.querySelector(`#arquivo_${id}`).dataset.status === "processed";
    }, { id: ids.dele, antes }, { timeout: 30000 });
    if (!(await cliente.evaluate(() => window.semRecarregar))) throw new Error("The client's gallery reloaded instead of swapping the card");
    if (!recebidos.some((f) => f.includes(ids.dele))) throw new Error("His card didn't come over the cable");
    // The other file is the team's (no client): its card must never reach a cliente final.
    const vazados = recebidos.filter((f) => f.includes(ids.alheio) || f.includes(nomes.alheio));
    if (vazados.length) throw new Error(`Nobody's card reached the cliente final: ${vazados[0].slice(0, 200)}`);
  });

  await test("Cleanup", async () => {
    await contexto?.close();
    fs.rmSync(pasta, { recursive: true, force: true });
  });
});
