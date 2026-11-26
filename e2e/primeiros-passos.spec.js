// Primeiros passos 1/6 (decided 26/11/2026, canvas "Primeiros passos"): a
// new instance's empty lists say what each part is and what comes before
// it. Runs right after autenticacao, on the database it left (the dono and
// the company, nothing else) — and creates nothing: the dialogs it opens
// are cancelled, so the specs after it start as before.
const { BASE_URL, runSpec } = require("./support/runner");

runSpec("Primeiros passos E2E Tests", async ({ page, test }) => {
  const vazio = (id) => page.locator(`[data-estado-vazio='${id}']`);

  await test("Pedidos says what the first one needs, and its main action leads to the first missing part", async () => {
    await page.goto(`${BASE_URL}/pedidos`);
    await vazio("pedido").locator("h3", { hasText: "Nenhum pedido ainda" }).waitFor();
    const faltas = await vazio("pedido").locator("[data-falta]").evaluateAll((lis) => lis.map((li) => `${li.dataset.falta}:${li.dataset.ok}`));
    if (faltas.join(" ") !== "clientes:false artes:false moldes:false materiais:false") throw new Error(`What comes before: ${faltas.join(" ")}`);
    await vazio("pedido").locator("a.btn-primary[data-estado-vazio-acao]").click();
    await page.waitForURL("**/clients");
    await vazio("cliente").waitFor();
  });

  await test("Clientes' own action opens its dialog centered; Cancel closes it with nothing saved", async () => {
    await vazio("cliente").locator("button[data-estado-vazio-acao]").click();
    const dialogo = page.locator("dialog[open]");
    await dialogo.waitFor();
    const caixa = await dialogo.evaluate((d) => { const r = d.getBoundingClientRect(); return { left: r.left, right: window.innerWidth - r.right }; });
    if (Math.abs(caixa.left - caixa.right) > 4) throw new Error(`Dialog not centered: ${JSON.stringify(caixa)}`);
    await dialogo.locator('button:has-text("Cancel")').click();
    await dialogo.waitFor({ state: "hidden" });
    await vazio("cliente").waitFor();
  });

  await test("The empty Painel lists what it needs and leads to the turnos", async () => {
    await page.goto(`${BASE_URL}/painel`);
    const faltas = await vazio("painel").locator("[data-falta]").evaluateAll((lis) => lis.map((li) => li.dataset.falta));
    if (faltas.join(" ") !== "turnos ritmos pedidos_confirmados") throw new Error(`The Painel needs: ${faltas.join(" ")}`);
    await vazio("painel").locator("a.btn-primary").click();
    await page.waitForURL("**/parametros/turnos#turnos");
    await vazio("turnos").waitFor();
  });

  await test("The gallery's empty screen points at the upload above it", async () => {
    await page.goto(`${BASE_URL}/arquivos`);
    await vazio("arte").locator("[data-estado-vazio-acao]").click();
    await page.waitForURL("**/arquivos#upload");
    if (!(await page.locator("#upload").isVisible())) throw new Error("The upload section isn't there");
  });
});
