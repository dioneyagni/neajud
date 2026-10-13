// Etapa 2.6a (decided 13/10/2026): the DTF etiqueta. Three sizes uploaded out
// of order come back ordered by the file's measure — P, M, G whatever their
// names say alphabetically — each with its measure in cm; the team sets the
// etiqueta's own spacing on the film (blank = the dono's default), and the dono
// sets the film in Parâmetros.
const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");
const { BASE_URL, runSpec } = require("./support/runner");
const { submitUploadAndWait } = require("./support/upload");
const { waitForText } = require("./support/wait");

runSpec("Etiqueta DTF E2E Tests", async ({ page, test }) => {
  const U = Date.now();
  const nome = `SEQ${U}`;
  // Outside the repo: an "e2e-" prefix would be read as part of the name.
  const pasta = fs.mkdtempSync(path.join(os.tmpdir(), "etiqueta-dtf-"));

  // A square of lado px at 300 dpi: 200 px = 1,69 cm.
  function etiqueta(numero, rotulo, lado) {
    const destino = path.join(pasta, `${numero}-${nome} - ${rotulo}.tif`);
    execFileSync("convert", ["-size", `${lado}x${lado}`, "xc:#2a6", "-units", "PixelsPerInch", "-density", "300", destino]);
    return destino;
  }

  function cartao() {
    return page.locator(".stamp-card").filter({ hasText: nome });
  }

  await test("Three sizes uploaded out of order come back ordered by their measure", async () => {
    await page.goto(`${BASE_URL}/arquivos`);
    await page.selectOption('[data-upload-target="tipo"]', "dtf");
    await page.setInputFiles('input[type="file"]', [etiqueta(901, "G", 400), etiqueta(902, "P", 200), etiqueta(903, "M", 300)]);
    const grupo = page.locator(".conferencia-grupo");
    await grupo.first().waitFor({ timeout: 10000 });
    if ((await grupo.count()) !== 1) throw new Error("The three sizes aren't one etiqueta");
    await submitUploadAndWait(page, 3);
    const resumo = (await cartao().locator(".stamp-card-arte").innerText({ timeout: 10000 })).trim();
    // Alphabetically it would be G, M, P: the measure orders them.
    if (resumo !== "3 files · P, M, G") throw new Error(`The card sums up as ${resumo}`);
    await page.selectOption('[data-upload-target="tipo"]', "calcado");
  });

  await test("The etiqueta's page lists P, M, G each with its measure in cm", async () => {
    await cartao().locator("a").first().click();
    const lista = page.locator("#arte-arquivos");
    await lista.waitFor({ timeout: 10000 });
    const tamanhos = await lista.locator(".arte-arquivo-tamanho").allInnerTexts();
    if (tamanhos.join(",") !== "P,M,G") throw new Error(`Sizes listed as ${tamanhos}`);
    const medidas = await lista.locator(".arte-arquivo-medida").allInnerTexts();
    if (medidas.join(" | ") !== "1,69 × 1,69 cm | 2,54 × 2,54 cm | 3,39 × 3,39 cm") throw new Error(`Measures: ${medidas}`);
  });

  await test("The team sets the etiqueta's own spacing; blank goes back to the default", async () => {
    const secao = page.locator("#espacamento-dtf-section");
    if ((await secao.locator("#espacamento-dtf-mm").getAttribute("placeholder")) !== "1,5") throw new Error("The default isn't 1,5 mm");
    await secao.locator("#espacamento-dtf-mm").fill("2,5");
    await secao.locator('button[type="submit"]').click();
    await waitForText(page, ": 2,5 mm.");
    if ((await page.locator("#espacamento-dtf-mm").inputValue()) !== "2,5") throw new Error("The spacing wasn't kept");
    await page.locator("#espacamento-dtf-mm").fill("");
    await page.locator('#espacamento-dtf-section button[type="submit"]').click();
    await waitForText(page, ": 1,5 mm (the default).");
  });

  await test("The dono sets the DTF film in Parâmetros and sees the width left for etiquetas", async () => {
    await page.goto(`${BASE_URL}/parametros/edit`);
    const util = page.locator(".parametros-dtf-util");
    if ((await util.innerText()).trim() !== "570 mm left for the etiquetas.") throw new Error(`Useful width: ${await util.innerText()}`);
    await page.fill("#empresa_largura_filme_dtf_mm", "620");
    await page.fill("#empresa_margem_filme_dtf_mm", "20");
    await page.fill("#empresa_espacamento_dtf_mm", "2");
    await page.click('input[type="submit"][value="Save"]');
    await waitForText(page, "Production parameters saved.");
    if ((await util.innerText()).trim() !== "580 mm left for the etiquetas.") throw new Error(`Useful width after saving: ${await util.innerText()}`);
    // Back to the defaults: later specs read them.
    await page.fill("#empresa_largura_filme_dtf_mm", "600");
    await page.fill("#empresa_margem_filme_dtf_mm", "15");
    await page.fill("#empresa_espacamento_dtf_mm", "1,5");
    await page.click('input[type="submit"][value="Save"]');
    await waitForText(page, "Production parameters saved.");
  });

  await test("Cleanup", async () => {
    fs.rmSync(pasta, { recursive: true, force: true });
  });
});
