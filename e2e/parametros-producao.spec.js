// Painel 2/4a (decided 05/11/2026): the dono registers the turnos (an
// overlapping one is refused), adds a stage's day off in a dialog, confirms a
// national holiday and types a stage's rhythm; the Painel's header shows the
// turno on now; a trashed turno comes back from the Lixeira.
const { BASE_URL, runSpec } = require("./support/runner");
const { waitForText } = require("./support/wait");

runSpec("Turnos, calendário e ritmo E2E Tests", async ({ page, test }) => {
  const ano = new Date().getFullYear();
  const novo = 'form.turno-novo';

  async function adicionarTurno(nome, inicio, fim, dias) {
    await page.fill(`${novo} input[name="turno[nome]"]`, nome);
    await page.fill(`${novo} input[name="turno[inicio]"]`, inicio);
    await page.fill(`${novo} input[name="turno[fim]"]`, fim);
    for (const dia of dias) await page.check(`${novo} input[name="turno[dias][]"][value="${dia}"]`);
    await page.click(`${novo} input[type="submit"][value="Add turno"]`);
  }

  await test("Parameters links to the turnos page", async () => {
    await page.goto(`${BASE_URL}/parametros/edit`);
    await page.click('.parametros-links a:has-text("Turnos e calendário")');
    await page.waitForURL("**/parametros/turnos");
    await waitForText(page, "No turno yet");
  });

  await test("Adding Manhã and a Tarde that overlaps it: the second is refused, then saved at 14:00", async () => {
    await adicionarTurno("Manhã", "06:00", "14:00", [6]);
    await waitForText(page, "Turno Manhã saved.");
    if ((await page.locator('form[data-turno="Manhã"]').count()) !== 1) throw new Error("Manhã row missing");
    await adicionarTurno("Tarde", "13:00", "22:00", []);
    await waitForText(page, "overlaps Manhã 06:00–14:00 (seg a sáb) on seg 13:00");
    await adicionarTurno("Tarde", "14:00", "22:00", []);
    await waitForText(page, "Turno Tarde saved.");
    const dias = await page.locator('form[data-turno="Manhã"] input[name="turno[dias][]"]:checked').evaluateAll((c) => c.map((i) => i.value));
    if (dias.join(",") !== "1,2,3,4,5,6") throw new Error(`Manhã days are ${dias}, expected seg to sáb`);
  });

  await test("The exception dialog opens centered, Cancel closes it, and saving adds a Calandra day off", async () => {
    await page.click('button:has-text("New exception")');
    const dialogo = page.locator("dialog.calendario-dialog");
    await dialogo.waitFor({ state: "visible" });
    const caixa = await dialogo.evaluate((d) => { const r = d.getBoundingClientRect(); return { top: r.top, left: r.left, right: window.innerWidth - r.right, vh: window.innerHeight }; });
    if (caixa.top < 0 || caixa.top > caixa.vh * 0.4 || Math.abs(caixa.left - caixa.right) > 4) throw new Error(`Dialog not centered: ${JSON.stringify(caixa)}`);
    await dialogo.locator('button:has-text("Cancel")').click();
    await dialogo.waitFor({ state: "hidden" });

    await page.click('button:has-text("New exception")');
    await dialogo.locator("#excecao_nome").fill("Calandra parada");
    await dialogo.locator("#excecao_data").fill(`${ano}-12-01`);
    await dialogo.locator("#excecao_turno_uuid").selectOption({ label: "Tarde (14:00–22:00)" });
    await dialogo.locator("#excecao_etapa").selectOption({ label: "Calandra" });
    await dialogo.locator('input[type="submit"]').click();
    await waitForText(page, `Calandra parada (01/12/${ano}) saved.`);
    const linha = await page.locator('tr[data-excecao="Calandra parada"]').textContent();
    if (!linha.includes("Calandra · Tarde")) throw new Error(`Exception row says "${linha}"`);
  });

  await test("Confirming a national holiday, then taking it back", async () => {
    const feriado = page.locator(`li[data-feriado="${ano}-11-20"]`);
    await feriado.locator("button").click();
    await waitForText(page, "the factory stops on 20/11");
    if ((await page.locator(`li[data-feriado="${ano}-11-20"] .feriado-estado`).textContent()) !== "factory stops") throw new Error("Holiday not confirmed");
    await page.locator(`li[data-feriado="${ano}-11-20"] button`).click();
    await waitForText(page, "the factory works on 20/11");
  });

  await test("Typing and fixing the Calçado Impressão rhythm", async () => {
    await page.goto(`${BASE_URL}/parametros/ritmos/edit`);
    const linha = page.locator('tr[data-ritmo="calcado:impressao"]');
    if (!(await linha.textContent()).includes("not set")) throw new Error("Rhythm should start not set");
    await linha.locator('input[name="ritmos[calcado][impressao][por_hora]"]').fill("5,5");
    await linha.locator('input[type="checkbox"]').check();
    await page.click('.ritmos-form button[type="submit"]');
    await waitForText(page, "Production rhythm saved.");
    const depois = page.locator('tr[data-ritmo="calcado:impressao"]');
    if ((await depois.locator("input[type=text]").inputValue()) !== "5,5") throw new Error("Rhythm not kept");
    if (!(await depois.locator(".ritmo-em-uso").textContent()).includes("5,5 m/h")) throw new Error("Rhythm in use should be 5,5 m/h");
  });

  await test("The Painel's header shows today, the time and the turno — or the next one", async () => {
    await page.goto(`${BASE_URL}/painel`);
    const agora = (await page.locator("[data-painel-agora]").textContent()).trim();
    if (!/^(dom|seg|ter|qua|qui|sex|sáb) \d\d\/\d\d · \d\d:\d\d · (turno (Manhã|Tarde)|fora de turno · próximo: )/.test(agora)) throw new Error(`Header says "${agora}"`);
  });

  await test("Trashing Tarde, then restoring it from the Lixeira", async () => {
    await page.goto(`${BASE_URL}/parametros/turnos`);
    // The confirm ("Move turno Tarde to the trash?") is accepted by the runner.
    await page.click('form[data-turno="Tarde"] a:has-text("Trash")');
    await waitForText(page, "Turno Tarde moved to the trash.");
    await page.goto(`${BASE_URL}/lixeira`);
    await page.locator('section[data-tipo="turnos"] button:has-text("Restore")').click();
    await waitForText(page, 'Turno "Tarde" restored.');
  });
});
