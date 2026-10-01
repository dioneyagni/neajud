const path = require("path");
const fs = require("fs");
const { execSync } = require("child_process");
const { uploadFileAndWait } = require("./support/upload");
const { BASE_URL, runSpec } = require("./support/runner");
const { waitForText, waitForQueuedTask } = require("./support/wait");
const { modeloOficial } = require("./support/catalogo");

// Etapa 1.1 (5/5): an arte's Referência + Nome, read from the file name when
// the molde is chosen, its computed full name, and the same arte uploaded
// twice becoming a new version of the first.
runSpec("Arquivos: referência, nome and full name", async ({ page, test }) => {
  const UNIQ = `NA${Date.now()}`;
  const peca = `Lateral${UNIQ}`;
  const arquivos = { primeira: `19-BLUEY ${UNIQ}`, segunda: `e2e-repetida-${UNIQ}` };
  let ids = {};

  async function post(url, campos) {
    return page.evaluate(async ({ url, campos }) => {
      const token = document.querySelector('meta[name="csrf-token"]')?.content || "";
      return (await fetch(url, { method: "POST", body: new URLSearchParams({ authenticity_token: token, ...campos }) })).ok;
    }, { url, campos });
  }

  async function primeiroId(url, filtro) {
    return page.evaluate(async ({ url, filtro }) => (await (await fetch(url)).json()).find((r) => r[filtro.chave] === filtro.valor)?.id, { url, filtro });
  }

  // The file is deleted right after the upload, so it needs no "e2e-" prefix
  // for bin/e2e's cleanup — and a prefix would spoil the "19-…" being read.
  async function subirArte(nome) {
    const caminho = path.join(__dirname, `${nome}.tif`);
    execSync(`convert -size 60x60 xc:orange 'TIFF:${caminho}'`);
    try {
      await page.goto(BASE_URL);
      await uploadFileAndWait(page, caminho);
    } finally {
      if (fs.existsSync(caminho)) fs.unlinkSync(caminho);
    }
    return (await page.locator(".stamp-card").filter({ hasText: nome }).first().locator("a").first().getAttribute("href")).split("/").pop();
  }

  // Molde (official Tenis) + an organized corte with size 29-30 linked to it.
  await test("Setup: client, molde and a corte with size 29-30", async () => {
    const dxf = path.join(__dirname, `e2e-corte-na-${UNIQ}.dxf`);
    fs.copyFileSync(path.join(__dirname, "..", "spec", "fixtures", "files", "29-30.dxf"), dxf);
    try {
      await page.goto(BASE_URL);
      await uploadFileAndWait(page, dxf);
    } finally {
      if (fs.existsSync(dxf)) fs.unlinkSync(dxf);
    }
    ids.corte = (await page.locator(".stamp-card").filter({ hasText: `e2e-corte-na-${UNIQ}` }).first().locator("a").first().getAttribute("href")).split("/").pop();
    const tenis = await modeloOficial(page, "Tenis");
    await post("/clients", { "client[name]": `Nome Client ${UNIQ}`, "client[responsible]": "T" });
    ids.client = await primeiroId(`/clients/search?q=${encodeURIComponent(`Nome Client ${UNIQ}`)}`, { chave: "name", valor: `Nome Client ${UNIQ}` });
    await post("/pecas", { "peca[nome]": peca });
    ids.peca = await primeiroId(`/pecas/search?q=${encodeURIComponent(peca)}`, { chave: "nome", valor: peca });
    await post("/moldes", { "molde[sufixo]": `Nome Molde ${UNIQ}`, "molde[client_uuid]": ids.client, "molde[modelo_uuid]": tenis.id });
    ids.molde = await primeiroId(`/moldes/search?q=${encodeURIComponent(`Nome Molde ${UNIQ}`)}`, { chave: "sufixo", valor: `Nome Molde ${UNIQ}` });
    const ok = [
      await post(`/arquivos/${ids.corte}/update_client`, { _method: "patch", client_uuid: ids.client }),
      await post(`/arquivos/${ids.corte}/organize`, { _method: "patch", modelo_uuid: tenis.id, peca_uuid: ids.peca,
        "tamanhos[0][nome]": "29-30", "tamanhos[0][width_mm]": "150", "tamanhos[0][height_mm]": "250", "tamanhos[0][area_mm2]": "8000" }),
      await post(`/arquivos/${ids.corte}/add_molde`, { molde_uuid: ids.molde })
    ];
    if (ok.includes(false)) throw new Error(`Setup steps: ${ok}`);
    ids.tamanho = await primeiroId(`/tamanhos/for_cascade?molde_uuid=${ids.molde}&peca_uuid=${ids.peca}`, { chave: "nome", valor: "29-30" });
    if (!ids.tamanho) throw new Error("Corte size 29-30 not found");
  });

  await test("Choosing the molde reads referência 19 and the name from the file; the full name shows", async () => {
    ids.primeira = await subirArte(arquivos.primeira);
    await post(`/arquivos/${ids.primeira}/update_client`, { _method: "patch", client_uuid: ids.client });
    await post(`/arquivos/${ids.primeira}/update_molde`, { _method: "patch", molde_uuid: ids.molde });
    // Choosing the molde queues the automatic size search, which refreshes
    // the arte page when it ends: let it finish first, or the refresh lands
    // while the test types (seen in CI-like runs, 01/10/2026).
    await waitForQueuedTask(page, `/arquivos/${ids.primeira}/busca_tamanho.json`);
    await post(`/arquivos/${ids.primeira}/update_tamanho`, { _method: "patch", tamanho_uuid: ids.tamanho });
    await page.goto(`${BASE_URL}/arquivos/${ids.primeira}`);
    const esperado = `001-TNS_19_BLUEY ${UNIQ}_${peca}_29-30`;
    const nome = (await page.locator("#nome-arte-section .nome-completo").textContent()).trim();
    if (nome !== esperado) throw new Error(`Full name "${nome}", expected "${esperado}"`);
  });

  await test("Editing on the page: a new referência and another name change the full name", async () => {
    const secao = page.locator("#nome-arte-section");
    await secao.locator('input[name="nova_referencia"]').fill("Fuel");
    await secao.locator('input[name="nome"]').fill("Bluey Azul");
    await secao.locator('button[type="submit"]').click();
    await waitForText(page, `Reference and name saved: 001-TNS_Fuel_Bluey Azul_${peca}_29-30`);
    const opcoes = await page.locator("#nome-arte-section select[name='referencia_uuid'] option").allTextContents();
    if (!opcoes.includes("Fuel") || !opcoes.includes("19")) throw new Error(`Referências offered: ${opcoes.join(", ")}`);
  });

  await test("The same arte uploaded again offers to become a new version, and does", async () => {
    ids.segunda = await subirArte(arquivos.segunda);
    await post(`/arquivos/${ids.segunda}/update_client`, { _method: "patch", client_uuid: ids.client });
    await post(`/arquivos/${ids.segunda}/update_molde`, { _method: "patch", molde_uuid: ids.molde });
    // Choosing the molde queues the automatic size search, which refreshes
    // the arte page when it ends: let it finish first, or the refresh lands
    // while the test types (seen in CI-like runs, 01/10/2026).
    await waitForQueuedTask(page, `/arquivos/${ids.segunda}/busca_tamanho.json`);
    await post(`/arquivos/${ids.segunda}/update_tamanho`, { _method: "patch", tamanho_uuid: ids.tamanho });
    await page.goto(`${BASE_URL}/arquivos/${ids.segunda}`);
    // Same full name, typed in other case: the comparison ignores it.
    const secao = page.locator("#nome-arte-section");
    await secao.locator("select[name='referencia_uuid']").selectOption({ label: "Fuel" });
    await secao.locator('input[name="nome"]').fill("BLUEY AZUL");
    await secao.locator('button[type="submit"]').click();
    await waitForText(page, "Reference and name saved");

    await page.locator('button:has-text("Make it a new version of that arte")').click();
    await page.waitForURL(`**/arquivos/${ids.primeira}`);
    await waitForText(page, new RegExp(`${arquivos.segunda} is now version 2 of 001-TNS_Fuel_Bluey Azul`));
    await page.goto(`${BASE_URL}/lixeira`);
    await waitForText(page, arquivos.segunda);
  });
});
