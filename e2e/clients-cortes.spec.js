const path = require("path");
const fs = require("fs");
const { uploadFileAndWait } = require("./support/upload");
const { BASE_URL, runSpec } = require("./support/runner");
const { modeloOficial } = require("./support/catalogo");

// 01/10/2026: a client's cortes showed nowhere on its page. Not organized (or
// linked to no molde) → "Cortes não organizados"; organized and linked → under
// that molde.
runSpec("Client page: cortes", async ({ page, test }) => {
  const UNIQ = `CC${Date.now()}`;
  const nomes = { cliente: `Cortes Client ${UNIQ}`, molde: `Cortes Molde ${UNIQ}`, peca: `Cortes Peca ${UNIQ}`, corte: `e2e-corte-cliente-${UNIQ}` };
  let corteUuid, clienteUuid, moldeUuid, pecaUuid;

  async function post(url, campos) {
    return page.evaluate(async ({ url, campos }) => {
      const token = document.querySelector('meta[name="csrf-token"]')?.content || "";
      const r = await fetch(url, { method: "POST", body: new URLSearchParams({ authenticity_token: token, ...campos }) });
      return r.ok;
    }, { url, campos });
  }

  async function buscar(url, chave, valor) {
    return page.evaluate(async ({ url, chave, valor }) => (await (await fetch(url)).json()).find((r) => r[chave] === valor)?.id, { url, chave, valor });
  }

  await test("Setup: a client with a DXF that isn't organized yet", async () => {
    const dxfPath = path.join(__dirname, `${nomes.corte}.dxf`);
    fs.copyFileSync(path.join(__dirname, "..", "spec", "fixtures", "files", "29-30.dxf"), dxfPath);
    try {
      await page.goto(BASE_URL);
      await uploadFileAndWait(page, dxfPath);
    } finally {
      if (fs.existsSync(dxfPath)) fs.unlinkSync(dxfPath);
    }
    corteUuid = (await page.locator(".stamp-card").filter({ hasText: nomes.corte }).first().locator("a").first().getAttribute("href")).split("/").pop();
    await post("/clients", { "client[name]": nomes.cliente, "client[responsible]": "T" });
    clienteUuid = await buscar(`/clients/search?q=${encodeURIComponent(nomes.cliente)}`, "name", nomes.cliente);
    if (!(await post(`/arquivos/${corteUuid}/update_client`, { _method: "patch", client_uuid: clienteUuid }))) throw new Error("Could not give the corte its client");
  });

  await test("The client page lists it under 'Cortes não organizados', and it opens the corte", async () => {
    await page.goto(`${BASE_URL}/clients/${clienteUuid}`);
    const area = page.locator("#cortes-pendentes");
    await area.locator(".stamp-card").filter({ hasText: nomes.corte }).waitFor({ timeout: 5000 });
    if ((await area.locator(".badge-count").textContent()).trim() !== "1") throw new Error("The area should count 1 corte");
    await area.locator(".stamp-card").filter({ hasText: nomes.corte }).locator("a").first().click();
    await page.waitForURL(`**/arquivos/${corteUuid}`);
    await page.getByText("This DXF file is not organized yet").waitFor();
  });

  await test("Once organized and linked to the client's molde, it moves under that molde", async () => {
    const tenis = await modeloOficial(page, "Tenis");
    await post("/pecas", { "peca[nome]": nomes.peca });
    pecaUuid = await buscar(`/pecas/search?q=${encodeURIComponent(nomes.peca)}`, "nome", nomes.peca);
    await post("/moldes", { "molde[sufixo]": nomes.molde, "molde[client_uuid]": clienteUuid, "molde[modelo_uuid]": tenis.id });
    moldeUuid = await buscar(`/moldes/search?q=${encodeURIComponent(nomes.molde)}`, "sufixo", nomes.molde);
    const organizado = await post(`/arquivos/${corteUuid}/organize`, {
      _method: "patch", modelo_uuid: tenis.id, peca_uuid: pecaUuid,
      "tamanhos[0][nome]": "29-30", "tamanhos[0][width_mm]": "150", "tamanhos[0][height_mm]": "250", "tamanhos[0][area_mm2]": "8000"
    });
    const ligado = await post(`/arquivos/${corteUuid}/add_molde`, { molde_uuid: moldeUuid });
    if (!organizado || !ligado) throw new Error(`organize ok=${organizado}, add_molde ok=${ligado}`);

    await page.goto(`${BASE_URL}/clients/${clienteUuid}`);
    const doMolde = page.locator(".stamp-detail-section").filter({ hasText: nomes.molde }).locator(".cliente-molde-cortes .stamp-card").filter({ hasText: nomes.corte });
    await doMolde.waitFor({ timeout: 5000 });
    // Nothing pending any more, so the area is gone (it is a to-do list).
    if (await page.locator("#cortes-pendentes").count() !== 0) throw new Error("The pending area should disappear once every corte is organized and linked");
  });
});
