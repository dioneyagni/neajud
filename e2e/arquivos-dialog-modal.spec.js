// Regression (29/09/2026): creating a molde from the arte page's "Register new
// model" dialog redirected back to the same page; the morph render removed the
// dialog's `open` attribute but left it in the top layer, so the whole page
// went inert and every click landed on <html> until a reload.
// Also: the model search typed "?q=" onto a URL that already had "?client_id=".
const path = require("path");
const fs = require("fs");
const { execSync } = require("child_process");
const { uploadFileAndWait } = require("./support/upload");
const { BASE_URL, runSpec } = require("./support/runner");
const { waitForText } = require("./support/wait");

runSpec("Arquivos E2E: dialogs never leave the page inert", async ({ page, test }) => {
  const UNIQ = `D${Date.now()}`;
  const arteName = `e2e-dialog-${UNIQ}`;
  const moldeName = `Dialog Molde ${UNIQ}`;
  let arteUuid = null;

  await test("Setup: an arte with a client", async () => {
    const artePath = path.join(__dirname, `${arteName}.tif`);
    try {
      execSync(`convert -size 30x30 xc:navy 'TIFF:${artePath}'`);
      await page.goto(BASE_URL);
      await uploadFileAndWait(page, artePath);
    } finally {
      if (fs.existsSync(artePath)) fs.unlinkSync(artePath);
    }
    arteUuid = (await page.locator(`.stamp-card[data-filename="${arteName}"] a`).first().getAttribute("href")).split("/").pop();
    const ok = await page.evaluate(async ({ uuid, uniq }) => {
      const token = document.querySelector('meta[name="csrf-token"]')?.content || "";
      const post = (url, fields) => fetch(url, { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({ authenticity_token: token, ...fields }) });
      await post("/clients", { "client[name]": `Dialog Client ${uniq}`, "client[responsible]": "T" });
      const client = (await (await fetch(`/clients/search?q=${encodeURIComponent(`Dialog Client ${uniq}`)}`)).json())[0];
      return (await post(`/arquivos/${uuid}/update_client`, { _method: "patch", client_uuid: client.id })).ok;
    }, { uuid: arteUuid, uniq: UNIQ });
    if (!ok) throw new Error("Could not link a client to the arte");
  });

  await test("Creating a model from the dialog keeps the page clickable", async () => {
    await page.goto(`${BASE_URL}/arquivos/${arteUuid}`);
    const secao = page.locator("#molde-field-section");
    await secao.locator(".btn-edit").click();
    await secao.locator(".combobox-input").fill("x");
    await secao.locator(".combobox-option-new").click();
    const dialogo = secao.locator("dialog[open]");
    await dialogo.waitFor();
    await dialogo.locator('input[name="molde[nome]"]').fill(moldeName);
    await dialogo.locator('button[type="submit"]').click();
    await waitForText(page, "Molde registered.");

    const estado = await page.evaluate(() => {
      const link = [...document.querySelectorAll("a")].find((a) => a.textContent.includes("Back to Gallery"));
      link.scrollIntoView({ block: "center" });
      const r = link.getBoundingClientRect();
      const noPonto = document.elementFromPoint(r.x + r.width / 2, r.y + r.height / 2);
      return { abertos: document.querySelectorAll("dialog[open]").length, alcancaLink: link.contains(noPonto), noPonto: noPonto?.tagName };
    });
    if (estado.abertos !== 0) throw new Error(`${estado.abertos} dialog(s) still open after the redirect`);
    if (!estado.alcancaLink) throw new Error(`A click would land on <${estado.noPonto}>, not on the link: the page is inert`);
    await page.click('a:has-text("Back to Gallery")');
    await page.waitForURL(`${BASE_URL}/arquivos`);
  });

  await test("The model search sends the typed text along with the client", async () => {
    await page.goto(`${BASE_URL}/arquivos/${arteUuid}`);
    const secao = page.locator("#molde-field-section");
    await secao.locator(".btn-edit").click();
    const [requisicao] = await Promise.all([
      page.waitForRequest((r) => r.url().includes("/moldes/for_client") && r.url().includes("q=Dialog")),
      secao.locator(".combobox-input").fill("Dialog")
    ]);
    const url = new URL(requisicao.url());
    if (!url.searchParams.get("client_uuid") || url.searchParams.get("client_uuid").includes("?")) throw new Error(`Malformed search URL: ${requisicao.url()}`);
    await secao.locator(".combobox-option").filter({ hasText: moldeName }).first().waitFor();
  });

  // Regression (29/09/2026): the edit dialog's required client select had no
  // option for a trashed client, so saving such a molde was silently blocked;
  // the trashed client must not be offered when creating, though.
  await test("A molde whose client is in the trash can be edited; creating doesn't offer that client", async () => {
    await page.goto(`${BASE_URL}/moldes`);
    const trashed = await page.evaluate(async (uniq) => {
      const token = document.querySelector('meta[name="csrf-token"]')?.content || "";
      const client = (await (await fetch(`/clients/search?q=${encodeURIComponent(`Dialog Client ${uniq}`)}`)).json())[0];
      const r = await fetch(`/clients/${client.id}`, { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({ authenticity_token: token, _method: "delete" }) });
      return r.ok ? client.id : null;
    }, UNIQ);
    if (!trashed) throw new Error("Could not trash the client");

    await page.goto(`${BASE_URL}/moldes`);
    const linha = page.locator(".clients-table tbody tr").filter({ hasText: moldeName });
    await linha.locator("button:has-text('Edit')").click();
    const dialogo = page.locator("dialog[open]");
    const valor = await dialogo.locator("#molde_client_uuid_dialog").inputValue();
    if (valor !== String(trashed)) throw new Error(`Client select is "${valor}", expected the trashed client ${trashed}`);
    await dialogo.locator("#molde_nome_dialog").fill(`${moldeName} Editado`);
    await dialogo.locator("button[type='submit']").click();
    await waitForText(page, "Molde updated.");

    await page.click("button:has-text('New Molde')");
    const oferecido = await page.locator(`dialog[open] #molde_client_uuid_dialog option[value="${trashed}"]`).evaluate((o) => !o.hidden && !o.disabled);
    if (oferecido) throw new Error("The trashed client is offered when creating a molde");
  });
});
