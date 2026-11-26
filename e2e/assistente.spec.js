// Primeiros passos 2/6a (decided 20/11 and 26/11/2026, canvas "Primeiros
// passos", 7–13): autenticacao left the wizard with "Fazer depois"; the
// Painel reminds the dono, "Continuar de onde parei" goes back to it, and
// it walks to the end — Voltar keeping what was marked, the Máquinas step
// skipped. Last in E2E_SPECS: it marks the kinds and creates materials.
const { BASE_URL, runSpec } = require("./support/runner");
const { waitForText } = require("./support/wait");

runSpec("Assistente E2E Tests", async ({ page, test }) => {
  const avancar = () => page.locator("input.assistente-avancar").click();

  await test("The Painel reminds the dono of the wizard left halfway and takes him back to it", async () => {
    await page.goto(`${BASE_URL}/painel`);
    const aviso = page.locator("[data-aviso-do-assistente]");
    await aviso.waitFor();
    if (!(await aviso.innerText()).includes("Faltam 5 de 5 passos")) throw new Error(`The reminder says "${await aviso.innerText()}"`);
    await aviso.locator('a:has-text("Continuar de onde parei")').click();
    await page.waitForURL("**/assistente/produz");
  });

  await test("What they produce is saved; Voltar brings it back marked", async () => {
    for (const tipo of ["calcado", "dtf"]) await page.locator(`[data-tipo='${tipo}'] input`).check();
    await avancar();
    await page.waitForURL("**/assistente/quem");
    await page.locator('a:has-text("Voltar")').click();
    await page.waitForURL("**/assistente/produz");
    if (!(await page.locator("[data-tipo='dtf'] input").isChecked())) throw new Error("DTF came back unchecked");
    await avancar();
    await page.waitForURL("**/assistente/quem");
  });

  await test("Funções and horário go on; the turnos already there show as done", async () => {
    await avancar();
    await page.waitForURL("**/assistente/horario");
    await page.locator("[data-turno-feito]").first().waitFor();
    await avancar();
    await page.waitForURL("**/assistente/maquinas");
  });

  await test("Máquinas offers the kinds' trabalhos only, and can be skipped", async () => {
    const opcoes = await page.locator("select[name='assistente[maquinas][][trabalho]']").first().locator("option").allInnerTexts();
    if (opcoes.join(" | ") !== "Impressão em papel | Corte do calçado | Estamparia | Impressão DTF | Corte do DTF") throw new Error(`Trabalhos offered: ${opcoes.join(" | ")}`);
    await page.locator('a:has-text("Pular este passo")').click();
    await page.waitForURL("**/assistente/materiais");
  });

  await test("Concluir registers the typical materials and ends on the Painel, the reminder gone", async () => {
    if (!(await page.locator("[data-material='filme_dtf']").count())) throw new Error("The DTF film isn't offered");
    await page.locator("input.assistente-avancar[value='Concluir']").click();
    await page.waitForURL("**/painel");
    await waitForText(page, "Pronto! A fábrica está configurada.");
    // Ended, the wizard reminds no one.
    if (await page.locator("[data-aviso-do-assistente]").count()) throw new Error("The reminder stayed after Concluir");
  });
});
