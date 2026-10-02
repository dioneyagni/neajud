const path = require("path");
const fs = require("fs");
const { uploadFileAndWait } = require("./support/upload");
const { waitForQueuedTask } = require("./support/wait");
const { BASE_URL, runSpec } = require("./support/runner");
const { modeloOficial } = require("./support/catalogo");

// Etapa 1.2 (1/3): a corte's grade type, deduced from the detected size names
// ("CABEDAL - 35 AO 43.dxf": 35, 37 … 43 → Ímpar 34-35 … 42-43), checked per type on save,
// and the molde's grade coverage shown as a warning (never a block).
runSpec("Arquivos E2E: corte grade type", async ({ page, test }) => {
  const UNIQ = `TG${Date.now()}`;
  const nomes = { corte: `e2e-grade-${UNIQ}`, cliente: `Grade Client ${UNIQ}`, molde: `Grade Molde ${UNIQ}` };
  let corteUuid;

  async function post(url, campos) {
    return page.evaluate(async ({ url, campos }) => {
      const token = document.querySelector('meta[name="csrf-token"]')?.content || "";
      return (await fetch(url, { method: "POST", body: new URLSearchParams({ authenticity_token: token, ...campos }) })).ok;
    }, { url, campos });
  }

  async function buscar(url, chave, valor) {
    return page.evaluate(async ({ url, chave, valor }) => (await (await fetch(url)).json()).find((r) => r[chave] === valor)?.id, { url, chave, valor });
  }

  const select = () => page.locator('select[name="tipo_grade"]');
  const campos = () => page.locator(".mold-organization-form .tamanho-input");
  const rotulos = () => page.locator(".mold-organization-form .tamanho-rotulo");

  await test("The organization proposes the type deduced from the size names", async () => {
    // The sizes are read from the range in the filename ("35 AO 43").
    const dxfPath = path.join(__dirname, `${nomes.corte} - 35 AO 43.dxf`);
    fs.copyFileSync(path.join(__dirname, "..", "spec", "fixtures", "files", "CABEDAL - 35 AO 43.dxf"), dxfPath);
    try {
      await page.goto(BASE_URL);
      await uploadFileAndWait(page, dxfPath);
    } finally {
      if (fs.existsSync(dxfPath)) fs.unlinkSync(dxfPath);
    }
    await Promise.all([
      page.waitForURL(/\/arquivos\/[0-9a-f-]{36}$/),
      page.locator(".stamp-card").filter({ hasText: nomes.corte }).first().locator("a").first().click()
    ]);
    corteUuid = page.url().split("/").pop();

    if ((await select().inputValue()) !== "impar") throw new Error(`Expected the deduced type "impar", got "${await select().inputValue()}"`);
    await page.getByText("deduced from the sizes' names").waitFor();
    const valores = await campos().evaluateAll((els) => els.map((el) => el.value));
    if (valores.join("|") !== "34-35|36-37|38-39|40-41|42-43") throw new Error(`Unexpected deduced sizes: ${valores.join("|")}`);
    // Ímpar builds the label from the pair, so the label column stays out of the way.
    if (await rotulos().first().isVisible()) throw new Error("The label column must be hidden for Ímpar");
  });

  await test("P/M/G and Furada show the label column; Ímpar hides it again", async () => {
    await select().selectOption("pmg");
    await rotulos().first().waitFor({ state: "visible" });
    await select().selectOption("furada");
    await rotulos().first().waitFor({ state: "visible" });
    await select().selectOption("impar");
    await rotulos().first().waitFor({ state: "hidden" });
  });

  await test("A size that doesn't fit the type is refused and nothing is saved", async () => {
    await campos().first().fill("35-36");
    await Promise.all([
      page.waitForResponse((r) => r.url().endsWith(`/arquivos/${corteUuid}/organize`)),
      page.click('.mold-organization-form button[type="submit"]')
    ]);
    await page.getByText("Size 1: \"35-36\" isn't a Ímpar pair").waitFor({ timeout: 5000 });
    await page.reload();
    await page.getByText("This DXF file is not organized yet").waitFor();
  });

  await test("Saving keeps the type and shows each size's pair", async () => {
    await campos().first().fill("35");
    await Promise.all([
      page.waitForResponse((r) => r.url().endsWith(`/arquivos/${corteUuid}/organize`)),
      page.click('.mold-organization-form button[type="submit"]')
    ]);
    await page.locator(".tipo-grade-display").filter({ hasText: "Grade: Ímpar" }).waitFor({ timeout: 5000 });
    const nomesSalvos = await page.locator(".tamanho-list--readonly .tamanho-nome").allTextContents();
    if (nomesSalvos.join("|") !== "34-35|36-37|38-39|40-41|42-43") throw new Error(`Unexpected saved sizes: ${nomesSalvos.join("|")}`);
    await waitForQueuedTask(page, `/arquivos/${corteUuid}/preparacao_tamanhos.json`);
  });

  await test("A molde whose grade the corte doesn't cover gets a warning on the corte page", async () => {
    const tenis = await modeloOficial(page, "Tenis");
    await post("/clients", { "client[name]": nomes.cliente, "client[responsible]": "T" });
    const clienteUuid = await buscar(`/clients/search?q=${encodeURIComponent(nomes.cliente)}`, "name", nomes.cliente);
    await post("/moldes", { "molde[sufixo]": nomes.molde, "molde[client_uuid]": clienteUuid, "molde[modelo_uuid]": tenis.id,
      "molde[tamanho_inicial]": "34", "molde[tamanho_final]": "44" });
    const moldeUuid = await buscar(`/moldes/search?q=${encodeURIComponent(nomes.molde)}`, "sufixo", nomes.molde);
    if (!moldeUuid) throw new Error("Could not create the molde");
    if (!(await post(`/arquivos/${corteUuid}/add_molde`, { molde_uuid: moldeUuid }))) throw new Error("Could not link the corte to the molde");

    await page.goto(`${BASE_URL}/arquivos/${corteUuid}`);
    await page.locator(".aviso-cobertura-grade").filter({ hasText: "falta 44" }).waitFor({ timeout: 5000 });
    // Only a warning (decided 01/10/2026): the corte stays organized and downloadable.
    if ((await page.locator(".tamanho-download").count()) !== 5) throw new Error("The warning must not hide the sizes' downloads");
  });
});
