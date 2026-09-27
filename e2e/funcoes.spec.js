// Etapa 0.5 (2/4): the dono edits what each função may do (a grid of levels
// per área + special actions), creates funções and deletes unused ones.
const { BASE_URL, runSpec } = require("./support/runner");
const { waitForText } = require("./support/wait");

runSpec("Funções E2E Tests", async ({ page, test }) => {
  const nova = `Expedição ${Date.now()}`;
  const coluna = (nome) => `th.funcao-coluna[data-funcao="${nome}"]`;
  const celula = (area, nome) => `tr[data-area="${area}"] td[data-funcao="${nome}"] select`;

  await test("The dono opens Funções from the menu and sees the default grid", async () => {
    await page.goto(BASE_URL);
    await page.click('.header-nav a:has-text("Funções")');
    await page.waitForURL("**/funcoes");
    for (const nome of ["Dono", "Admin", "Atendimento", "Designer", "Produção"]) {
      if ((await page.locator(coluna(nome)).count()) !== 1) throw new Error(`Column "${nome}" missing`);
    }
    const lixeira = await page.locator(celula("lixeira", "Designer")).locator("option").allTextContents();
    if (lixeira.join(",") !== "—,Ver,Restaurar") throw new Error(`Lixeira levels are "${lixeira}", expected —,Ver,Restaurar`);
  });

  // The Dono função has everything; editing it could lock the owner out.
  await test("The Dono column has no editable fields", async () => {
    const campos = await page.locator('td[data-funcao="Dono"] select, td[data-funcao="Dono"] input').count();
    if (campos !== 0) throw new Error(`Dono column has ${campos} editable fields`);
  });

  await test("Creating a função adds a column with nothing allowed", async () => {
    await page.fill('input[name="funcao[nome]"]', nova);
    await page.click('input[type="submit"][value="+ New função"]');
    await page.waitForSelector(coluna(nova));
    const valores = await page.locator(`td[data-funcao="${nova}"] select`).evaluateAll((selects) => selects.map((s) => s.value));
    if (valores.some((v) => v !== "0")) throw new Error(`New função should start at — everywhere, got ${valores}`);
  });

  await test("Changing levels and saving keeps them after a reload", async () => {
    await page.selectOption(celula("pedidos", nova), { label: "Editar" });
    await page.selectOption(celula("lixeira", nova), { label: "Restaurar" });
    await page.check(`tr[data-acao="baixar_producao"] td[data-funcao="${nova}"] input[type="checkbox"]`);
    await page.click('#funcoes-grade button[type="submit"]:has-text("Save")');
    await waitForText(page, "Funções saved.");
    await page.reload();
    const pedidos = await page.locator(celula("pedidos", nova)).inputValue();
    const lixeira = await page.locator(celula("lixeira", nova)).inputValue();
    const baixar = await page.locator(`tr[data-acao="baixar_producao"] td[data-funcao="${nova}"] input[type="checkbox"]`).isChecked();
    if (pedidos !== "2" || lixeira !== "2" || !baixar) throw new Error(`Saved values: pedidos=${pedidos} lixeira=${lixeira} baixar=${baixar}`);
  });

  await test("Deleting an unused função moves it to the trash", async () => {
    await page.locator(`td[data-funcao="${nova}"] button:has-text("Delete")`).click();
    await waitForText(page, `Função "${nova}" moved to the trash`);
    if ((await page.locator(coluna(nova)).count()) !== 0) throw new Error("Deleted função still has a column");
    await page.goto(`${BASE_URL}/lixeira`);
    if ((await page.locator(".lixeira-item").filter({ hasText: nova }).count()) !== 1) throw new Error("Função not in the trash");
  });

  // The dono's own função is in use (by the dono), so it can never be deleted.
  await test("Funções in use have no Delete button", async () => {
    await page.goto(`${BASE_URL}/funcoes`);
    if ((await page.locator('td[data-funcao="Dono"] button:has-text("Delete")').count()) !== 0) throw new Error("Dono has a Delete button");
  });
});
