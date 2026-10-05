const path = require("path");
const fs = require("fs");
const { submitUploadAndWait } = require("./support/upload");
const { BASE_URL, runSpec } = require("./support/runner");

// Etapa 1.2 (2/3): an arte is one envelope of files, one per part × size —
// one card in the gallery, the list on its page; files grouped apart or
// together by mistake are joined or separated by hand (decided 02/10/2026).
runSpec("Artes: files per part and size", async ({ page, test }) => {
  const UNIQ = `AA${Date.now()}`;
  const nomes = { p: `e2e-arte-${UNIQ}-29_30`, g: `e2e-arte-${UNIQ}-31_32` };
  const fixture = path.join(__dirname, "..", "spec", "fixtures", "files", "01-no_spot.tif");
  const cards = () => page.locator(".stamp-card").filter({ hasText: UNIQ });
  const linhas = () => page.locator("#arte-arquivos .arte-arquivo");

  async function abrirCard(nome) {
    await page.goto(BASE_URL);
    await Promise.all([
      page.waitForURL(/\/arquivos\/[0-9a-f-]{36}$/),
      page.locator(".stamp-card").filter({ hasText: nome }).first().locator("a").first().click()
    ]);
  }

  // Etapa 1.2 (2/3, parte 3): same name = one arte at upload; "Separate" in
  // the conference keeps them apart (the next steps join them by hand).
  await test("Separated in the upload's conference, two files are two artes, each with the size read from its name", async () => {
    const caminhos = Object.values(nomes).map((nome) => path.join(__dirname, `${nome}.tif`));
    caminhos.forEach((c) => fs.copyFileSync(fixture, c));
    try {
      await page.goto(BASE_URL);
      await page.setInputFiles('input[type="file"]', caminhos);
      await page.locator(".conferencia-grupo").waitFor();
      await page.locator(".conferencia-arquivo").filter({ hasText: nomes.g }).locator(".conferencia-separar").click();
      if ((await page.locator(".conferencia-grupo").count()) !== 2) throw new Error("Separate should leave two groups");
      await submitUploadAndWait(page, 2);
    } finally {
      caminhos.forEach((c) => fs.existsSync(c) && fs.unlinkSync(c));
    }
    await page.goto(BASE_URL);
    if ((await cards().count()) !== 2) throw new Error(`Expected 2 cards, got ${await cards().count()}`);
    // Both must have a preview: the join cards below show it.
    const estados = await cards().evaluateAll((els) => els.map((el) => el.dataset.status));
    if (estados.some((e) => e !== "processed")) throw new Error(`Expected both files processed, got ${estados.join(", ")}`);
    await abrirCard(nomes.p);
    const tamanho = (await linhas().first().locator(".arte-arquivo-tamanho").innerText()).trim();
    if (tamanho !== "29-30") throw new Error(`Expected the size 29-30 read from the name, got "${tamanho}"`);
  });

  await test("Bringing the other arte in: filter, mark its preview card, join", async () => {
    await page.locator(".arte-juntar summary").click();
    const botao = page.locator('.arte-juntar-form button[type="submit"]');
    if (!(await botao.isDisabled())) throw new Error("Nothing marked yet: the button must be disabled");

    // The filter leaves only the cards whose title, file or sizes match.
    await page.fill(".arte-juntar-busca", "31_32");
    const visiveis = page.locator(".arte-candidata--card:visible");
    await visiveis.first().waitFor();
    const textos = await visiveis.allInnerTexts();
    if (!textos.length || !textos.every((t) => t.includes("31_32"))) throw new Error(`The filter should leave only the 31_32 arte, got ${JSON.stringify(textos)}`);

    const card = page.locator(".arte-candidata--card").filter({ hasText: nomes.g });
    // The file's own preview (not the format icon shown while there is none), loaded.
    const img = card.locator("img");
    if (!(await img.getAttribute("src")).includes("/preview")) throw new Error(`The candidate shows no preview: ${await img.getAttribute("src")}`);
    // loading="lazy": wait for it rather than read it right away.
    await page.waitForFunction((el) => el.complete && el.naturalWidth > 0, await img.elementHandle(), { timeout: 5000 });
    await card.click();
    if ((await botao.innerText()).trim() !== "Bring the marked arte") throw new Error(`Unexpected button text: ${await botao.innerText()}`);
    await Promise.all([ page.waitForURL(/\/arquivos\/[0-9a-f-]{36}$/), botao.click() ]);
    await page.getByText("Joined into this arte:").waitFor();
    // Each file of the arte has its thumbnail.
    if ((await page.locator("#arte-arquivos .arte-arquivo .arte-arquivo-thumb").count()) !== 2) throw new Error("Each file should show its thumbnail");

    const tamanhos = await linhas().locator(".arte-arquivo-tamanho").allInnerTexts();
    if (tamanhos.join("|") !== "29-30|31-32") throw new Error(`Expected 29-30|31-32 in the arte, got ${tamanhos.join("|")}`);
    await page.goto(BASE_URL);
    if ((await cards().count()) !== 1) throw new Error(`Expected one card for the joined arte, got ${await cards().count()}`);
    if (!(await cards().first().locator(".stamp-card-arte").innerText()).includes("2 files")) throw new Error("The card should say the arte has 2 files");
  });

  // Etapa 1.2 (2/3, parte 2): one request and one approval cover the arte.
  await test("Approving from one file approves the arte: the other file's page and the card show it", async () => {
    await abrirCard(UNIQ);
    const outro = linhas().filter({ hasText: "31-32" }).locator("a.arte-arquivo-nome");
    const outroHref = await outro.getAttribute("href");
    await page.click('#aprovacao-section button:has-text("Send for approval")');
    await page.getByText("sent for approval (2 files)").waitFor();
    await page.click('#aprovacao-section a:has-text("Register approval")');
    await page.waitForURL(/\/aprovacoes\/new/);
    await page.check('input[name="aprovacao[canal]"][value="whatsapp"]');
    await Promise.all([ page.waitForURL(/\/arquivos\/[0-9a-f-]{36}$/), page.click('input[type="submit"][value="Register approval"]') ]);
    await page.getByText("registered (2 files)").waitFor();

    await page.goto(new URL(outroHref, BASE_URL).href);
    await page.locator("#aprovacao-section .badge-aprovacao--aprovada").waitFor();
    await page.goto(BASE_URL);
    const selo = (await cards().first().locator(".badge-aprovacao--aprovada").innerText()).trim();
    if (selo !== "✅ Aprovada") throw new Error(`The card should show the arte approved, got "${selo}"`);
  });

  await test("Adding a file of another size from the arte page", async () => {
    await abrirCard(UNIQ);
    await page.locator(".arte-acrescentar summary").click();
    await page.setInputFiles(".arte-acrescentar-form input[type=file]", fixture);
    await page.fill('.arte-acrescentar-form input[name="tamanho_rotulo"]', "33-34");
    await Promise.all([ page.waitForURL(/\/arquivos\/[0-9a-f-]{36}$/), page.locator('.arte-acrescentar-form button[type="submit"]').click() ]);
    await page.getByText("added to this arte (33-34)").waitFor();
    const tamanhos = await linhas().locator(".arte-arquivo-tamanho").allInnerTexts();
    if (tamanhos.join("|") !== "29-30|31-32|33-34") throw new Error(`Expected 3 sizes, got ${tamanhos.join("|")}`);
    // Added after the approval: the arte stays approved, the new file says so.
    if (!(await linhas().filter({ hasText: "33-34" }).innerText()).includes("after the approval")) throw new Error("The added file should be marked as after the approval");
    await page.locator("#aprovacao-section .badge-aprovacao--aprovada").waitFor();
  });

  // Etapa 1.2 (2/3, parte 2b): each part's piloto, the editable master.
  await test("Making a file the piloto lists it first, as the piloto; back to production undoes it", async () => {
    const linha = linhas().filter({ hasText: "33-34" });
    const uuid = await linha.getAttribute("data-arquivo-uuid");
    await Promise.all([ page.waitForResponse((r) => r.url().endsWith("/arte/tornar_piloto")), linha.locator(".arte-tornar-piloto button").click() ]);
    await page.getByText("is now the piloto of").waitFor();
    const primeira = linhas().first();
    if ((await primeira.getAttribute("data-arquivo-uuid")) !== uuid) throw new Error("The piloto should come first in its part");
    if ((await primeira.locator(".arte-arquivo-tamanho").innerText()).trim() !== "★ Piloto") throw new Error("The piloto should be labelled ★ Piloto");

    await Promise.all([ page.waitForResponse((r) => r.url().endsWith("/arte/voltar_para_producao")), primeira.locator('button:has-text("Back to production")').click() ]);
    await page.getByText("is a production file again").waitFor();
  });

  await test("Separating a file makes it an arte of its own again", async () => {
    const linha = linhas().filter({ hasText: "31-32" });
    await Promise.all([ page.waitForResponse((r) => r.url().endsWith("/arte/separar")), linha.locator(".arte-separar button").click() ]);
    await page.getByText("is now an arte of its own").waitFor();
    await page.goto(BASE_URL);
    if ((await cards().count()) !== 2) throw new Error(`Expected 2 cards after separating, got ${await cards().count()}`);
  });
});
