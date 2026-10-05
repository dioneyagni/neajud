const path = require("path");
const fs = require("fs");
const { uploadFileAndWait } = require("./support/upload");
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

  await test("Two files uploaded apart are two artes, each with the size read from its name", async () => {
    const caminhos = Object.values(nomes).map((nome) => path.join(__dirname, `${nome}.tif`));
    caminhos.forEach((c) => fs.copyFileSync(fixture, c));
    try {
      await page.goto(BASE_URL);
      await uploadFileAndWait(page, caminhos);
    } finally {
      caminhos.forEach((c) => fs.existsSync(c) && fs.unlinkSync(c));
    }
    await page.goto(BASE_URL);
    if ((await cards().count()) !== 2) throw new Error(`Expected 2 cards, got ${await cards().count()}`);
    await abrirCard(nomes.p);
    const tamanho = (await linhas().first().locator(".arte-arquivo-tamanho").innerText()).trim();
    if (tamanho !== "29-30") throw new Error(`Expected the size 29-30 read from the name, got "${tamanho}"`);
  });

  await test("Joining one into the other leaves one card and both files on the arte page", async () => {
    await page.locator(".arte-juntar summary").click();
    const opcao = page.locator('.arte-juntar-form select[name="destino_uuid"] option').filter({ hasText: nomes.g });
    await page.selectOption('.arte-juntar-form select[name="destino_uuid"]', await opcao.getAttribute("value"));
    await Promise.all([ page.waitForURL(/\/arquivos\/[0-9a-f-]{36}$/), page.locator('.arte-juntar-form button[type="submit"]').click() ]);
    await page.getByText("Joined:").waitFor();

    const tamanhos = await linhas().locator(".arte-arquivo-tamanho").allInnerTexts();
    if (tamanhos.join("|") !== "29-30|31-32") throw new Error(`Expected 29-30|31-32 in the arte, got ${tamanhos.join("|")}`);
    await page.goto(BASE_URL);
    if ((await cards().count()) !== 1) throw new Error(`Expected one card for the joined arte, got ${await cards().count()}`);
    if (!(await cards().first().locator(".stamp-card-arte").innerText()).includes("2 files")) throw new Error("The card should say the arte has 2 files");
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
  });

  await test("Separating a file makes it an arte of its own again", async () => {
    const linha = linhas().filter({ hasText: "31-32" });
    await Promise.all([ page.waitForResponse((r) => r.url().endsWith("/arte/separar")), linha.locator(".arte-separar button").click() ]);
    await page.getByText("is now an arte of its own").waitFor();
    await page.goto(BASE_URL);
    if ((await cards().count()) !== 2) throw new Error(`Expected 2 cards after separating, got ${await cards().count()}`);
  });
});
