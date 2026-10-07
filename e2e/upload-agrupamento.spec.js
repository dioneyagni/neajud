const path = require("path");
const fs = require("fs");
const os = require("os");
const { submitUploadAndWait } = require("./support/upload");
const { BASE_URL, runSpec } = require("./support/runner");

// Etapa 1.2 (2/3, parte 3; decided 05/10/2026): files with the same
// referência and nome are one arte at upload. A conference (only when
// something groups) shows each file's part and size read from its name and
// the suggested piloto, separates or joins groups, and offers an existing
// arte with the same name — never chosen for the user.
runSpec("Upload: grouping into artes", async ({ page, test }) => {
  const U = `${Date.now()}`.slice(-6);
  const pecas = { lat: `Lat${U}`, lin: `Lin${U}` };
  const fixtures = path.join(__dirname, "..", "spec", "fixtures", "files");
  // Outside the repo: the names must be the real ones (an "e2e-" prefix
  // would be read as part of the name), and nothing can be left in e2e/.
  const pasta = fs.mkdtempSync(path.join(os.tmpdir(), "neajud-agrupamento-"));

  function arquivo(nome, fixture = "02-no_spot.tif") {
    const caminho = path.join(pasta, nome);
    fs.copyFileSync(path.join(fixtures, fixture), caminho);
    return caminho;
  }

  async function escolher(caminhos) {
    await page.goto(BASE_URL);
    await page.setInputFiles('input[type="file"]', caminhos);
    await page.locator(".conferencia-grupo").first().waitFor();
  }

  const linha = (nome) => page.locator(".conferencia-arquivo").filter({ hasText: nome });

  try {
    await test("Setup: the two parts as the company's pieces", async () => {
      await page.goto(BASE_URL);
      for (const nome of Object.values(pecas)) {
        const ok = await page.evaluate(async (nome) => {
          const token = document.querySelector('meta[name="csrf-token"]')?.content || "";
          return (await fetch("/pecas", { method: "POST", body: new URLSearchParams({ authenticity_token: token, "peca[nome]": nome }) })).ok;
        }, nome);
        if (!ok) throw new Error(`Could not register the piece ${nome}`);
      }
    });

    await test("One arte's files become one group, with part, size and the editable file as piloto", async () => {
      await escolher([
        arquivo(`31-GATO${U}-${pecas.lat}.psd`, "01-no_spot.psd"), arquivo(`31-GATO${U}-${pecas.lat}-23_24.tif`),
        arquivo(`31-GATO${U}-${pecas.lat}-25_26.tif`), arquivo(`31-GATO${U}-${pecas.lin}-23_24.tif`), arquivo(`31-GATO${U}.tif`)
      ]);
      if ((await page.locator(".conferencia-grupo").count()) !== 1) throw new Error("Expected one group");
      const titulo = (await page.locator(".conferencia-grupo-titulo").innerText()).trim();
      if (titulo !== `31 · GATO${U}`) throw new Error(`Unexpected group title: ${titulo}`);
      if (!(await linha(".psd").locator('input[data-acao="piloto"]').isChecked())) throw new Error("The PSD should come as the piloto");
      const parte = await linha(`${pecas.lat}-25_26`).locator("select.conferencia-parte option:checked").innerText();
      const tamanho = await linha(`${pecas.lat}-25_26`).locator(".conferencia-tamanho").inputValue();
      if (parte !== pecas.lat || tamanho !== "25-26") throw new Error(`Part/size read from the name: ${parte} / ${tamanho}`);
      // Decided 05/10/2026: no part in the name stays empty, highlighted, for the person to choose.
      if ((await linha(`31-GATO${U}.tif`).locator(".conferencia-parte--vazia").count()) !== 1) throw new Error("A file without part should be highlighted");
      const botao = await page.inputValue('input[type="submit"]');
      if (botao !== "Upload 5 files in 1 artes") throw new Error(`Unexpected button: ${botao}`);
    });

    await test("Choosing the missing part and sending: one card, the files by part, the piloto first", async () => {
      await linha(`31-GATO${U}.tif`).locator("select.conferencia-parte").selectOption({ label: pecas.lin });
      await submitUploadAndWait(page, 5, 120000);
      const card = page.locator(".stamp-card").filter({ hasText: `GATO${U}` });
      if ((await card.count()) !== 1) throw new Error(`Expected one card for the arte, got ${await card.count()}`);
      await Promise.all([ page.waitForURL(/\/arquivos\/[0-9a-f-]{36}$/), card.locator("a").first().click() ]);
      const lateral = page.locator(`.arte-parte[data-parte="${pecas.lat}"] .arte-arquivo`);
      if ((await lateral.first().locator(".arte-arquivo-tamanho").innerText()).trim() !== "★ Piloto") throw new Error("The PSD should be the Lateral's piloto");
      if ((await lateral.count()) !== 3) throw new Error(`Expected 3 files in ${pecas.lat}, got ${await lateral.count()}`);
      if ((await page.locator(`.arte-parte[data-parte="${pecas.lin}"] .arte-arquivo`).count()) !== 2) throw new Error(`Expected 2 files in ${pecas.lin}`);
    });

    // Etapa 1.2 (3/3, parte 3c, decided 07/10/2026): "…-DIR" / "…-ESQ" is the
    // side of a mirrored part's file — one arte, each file with its side.
    await test("A part's right and left: one group, the side read from the name and saved", async () => {
      await escolher([ arquivo(`32-ONCA${U}-${pecas.lat}-29_30-DIR.tif`), arquivo(`32-ONCA${U}-${pecas.lat}-29_30-ESQ.tif`) ]);
      if ((await page.locator(".conferencia-grupo").count()) !== 1) throw new Error("DIR and ESQ should be one arte");
      const lado = (nome) => linha(nome).locator("select.conferencia-lado option:checked").innerText();
      if ((await lado("-DIR")) !== "DIR" || (await lado("-ESQ")) !== "ESQ") throw new Error(`Sides read: ${await lado("-DIR")} / ${await lado("-ESQ")}`);
      await submitUploadAndWait(page, 2, 120000);
      const card = page.locator(".stamp-card").filter({ hasText: `ONCA${U}` });
      await Promise.all([ page.waitForURL(/\/arquivos\/[0-9a-f-]{36}$/), card.locator("a").first().click() ]);
      const lados = await page.locator(`.arte-parte[data-parte="${pecas.lat}"] form.arte-lado select`).evaluateAll((s) => s.map((el) => el.value).sort());
      if (lados.join("|") !== "direito|esquerdo") throw new Error(`Saved sides: ${lados.join("|")}`);
    });

    await test("More sizes later: the conference offers the existing arte, and adds them to it when chosen", async () => {
      await escolher([ arquivo(`31-GATO${U}-${pecas.lat}-27_28.tif`), arquivo(`31-GATO${U}-${pecas.lat}-29_30.tif`) ]);
      const existente = page.locator(".conferencia-existente").filter({ hasText: `GATO${U}` });
      await existente.waitFor();
      // Never chosen for the user: "A new arte" comes checked.
      if (!(await page.locator('.conferencia-existente input[value=""]').isChecked())) throw new Error("A new arte should be the default");
      await existente.locator("input").check();
      await submitUploadAndWait(page, 2);
      if ((await page.locator(".stamp-card").filter({ hasText: `GATO${U}` }).count()) !== 1) throw new Error("The new sizes should go into the existing arte's card");
      const nomes = await page.locator(".stamp-card").filter({ hasText: `GATO${U}` }).getAttribute("data-arte-arquivos");
      if (nomes.split("|").length !== 7) throw new Error(`Expected 7 files in the arte, got ${nomes}`);
    });

    await test("Joining two groups of the same upload makes one arte", async () => {
      await escolher([ arquivo(`42-PATO${U}-23_24.tif`), arquivo(`42-PATO${U}-25_26.tif`), arquivo(`43-PATO${U}-27_28.tif`) ]);
      if ((await page.locator(".conferencia-grupo").count()) !== 2) throw new Error("42 and 43 are different referências: two groups");
      const grupo43 = page.locator(".conferencia-grupo").filter({ has: page.locator(".conferencia-grupo-titulo", { hasText: "43 · PATO" }) });
      await grupo43.locator("select.conferencia-juntar").selectOption({ label: `42 · PATO${U}` });
      if ((await page.locator(".conferencia-grupo").count()) !== 1) throw new Error("Joining should leave one group");
      await submitUploadAndWait(page, 3);
      if ((await page.locator(".stamp-card").filter({ hasText: `PATO${U}` }).count()) !== 1) throw new Error("The joined group should be one card");
    });
  } finally {
    fs.rmSync(pasta, { recursive: true, force: true });
  }
});
