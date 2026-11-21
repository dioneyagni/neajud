// Máquinas 1/5 (decided 20/11/2026, canvas "Máquinas"): the dono registers
// a machine doing two trabalhos (a speed typed only once checked), sees
// each trabalho's sum, a checked trabalho without speed is refused, Ritmos
// shows a row with machines read only, the Painel runs the Calandra at its
// machines' sum, a trashed machine comes back from the Lixeira and its name
// stays taken there. Last, every machine goes to the trash: the specs after
// this one type their rhythms in Ritmos.
const { BASE_URL, runSpec } = require("./support/runner");
const { prepararCorrida, pedidoDaCorrida, limparCorrida } = require("./support/corrida");
const { waitForText } = require("./support/wait");

runSpec("Máquinas E2E Tests", async ({ page, test }) => {
  const U = Date.now();
  const calandra = `Calandra ${U}`;
  const segunda = `Calandra B ${U}`;
  const epson = `Epson ${U}`;
  let corrida;
  let pedido;

  async function novaMaquina(nome, trabalhos) {
    await page.goto(`${BASE_URL}/parametros/maquinas/new`);
    await page.fill("#maquina_nome", nome);
    for (const [chave, velocidade] of Object.entries(trabalhos)) {
      const campo = page.locator(`[data-velocidade-de="${chave}"][name$="[por_hora]"]`);
      if (!(await campo.isDisabled())) throw new Error(`${chave}'s speed is open before it is checked`);
      await page.check(`#trabalho_${chave}`);
      await campo.fill(velocidade);
    }
    await page.click('button[form="maquina-form"]');
  }

  function linhaDoTrabalho(chave) {
    return page.locator(`tr[data-trabalho="${chave}"]`);
  }

  async function horasDaCalandra() {
    await page.goto(`${BASE_URL}/painel`);
    await page.locator(".painel-setor[data-setor='estamparia']").click();
    const vez = page.locator(`[data-fila-setor='estamparia'] [data-fila-pedido='${pedido}']`).first();
    await vez.waitFor();
    return (await vez.locator(".painel-fila-hora small").innerText()).trim();
  }

  await test("Parameters links to Máquinas, with no machine yet", async () => {
    await page.goto(`${BASE_URL}/parametros/edit`);
    await page.click('.parametros-links a:has-text("Máquinas")');
    await page.waitForURL("**/parametros/maquinas");
    if (!(await linhaDoTrabalho("calandra").innerText()).includes("nenhuma — usa o ritmo de Ritmos")) throw new Error("The Calandra has a machine already");
  });

  await test("A machine doing the Calandra and the Dublagem: saved, each trabalho shows it", async () => {
    await novaMaquina(calandra, { calandra: "25", dublagem: "30" });
    await waitForText(page, `${calandra}: salva.`);
    const linha = (await linhaDoTrabalho("calandra").innerText()).replace(/\s+/g, " ");
    if (!linha.includes(calandra) || !linha.includes("25 m/h")) throw new Error(`The Calandra's row says "${linha}"`);
    if (!(await linhaDoTrabalho("dublagem").innerText()).includes("30 m/h")) throw new Error("The Dublagem's row lacks 30 m/h");
    const chips = await page.locator(`tr[data-maquina="${calandra}"] .maquina-chip`).allInnerTexts();
    if (chips.join(" | ") !== "Calandra · 25 m/h | Dublagem · 30 m/h") throw new Error(`Its chips are ${chips.join(" | ")}`);
  });

  await test("A checked trabalho without speed is refused, the name typed kept", async () => {
    await page.goto(`${BASE_URL}/parametros/maquinas/new`);
    await page.fill("#maquina_nome", segunda);
    await page.check("#trabalho_calandra");
    await page.click('button[form="maquina-form"]');
    await waitForText(page, "Calandra: Velocidade precisa ser mais que 0");
    if ((await page.inputValue("#maquina_nome")) !== segunda) throw new Error("The name typed was lost");
    if (!(await page.isChecked("#trabalho_calandra"))) throw new Error("The Calandra came back unchecked");
  });

  await test("Ritmos shows the Calandra's row from its machine, read only", async () => {
    await page.goto(`${BASE_URL}/parametros/ritmos/edit`);
    const linha = page.locator('tr[data-ritmo="tecido:calandra"]');
    const texto = (await linha.locator("[data-das-maquinas]").innerText()).replace(/\s+/g, " ");
    if (!texto.includes("25 m/h · 1 máquina · ver máquinas")) throw new Error(`The Calandra's row says "${texto}"`);
    // A row with machines is typed in Máquinas, so Ritmos has no field for it.
    if (await linha.locator('input[name$="[por_hora]"]').count()) throw new Error("The Calandra's rhythm is still typed here");
    if (!(await page.locator('tr[data-ritmo="calcado:conferencia"] input[name$="[por_hora]"]').count())) throw new Error("The Conferência lost its field");
  });

  await test("The Painel runs the Calandra at its machines' sum: a second one halves its time", async () => {
    corrida = await prepararCorrida(page, "maq");
    pedido = await pedidoDaCorrida(page, corrida);
    await page.goto(`${BASE_URL}/parametros/turnos`);
    if (await page.getByText("No turno yet").count()) {
      const novo = "form.turno-novo";
      await page.fill(`${novo} input[name="turno[nome]"]`, "Máquinas 24h");
      await page.fill(`${novo} input[name="turno[inicio]"]`, "00:00");
      await page.fill(`${novo} input[name="turno[fim]"]`, "23:59");
      for (const dia of [0, 6]) await page.check(`${novo} input[name="turno[dias][]"][value="${dia}"]`);
      await page.click(`${novo} input[type="submit"][value="Add turno"]`);
      await waitForText(page, "Turno Máquinas 24h saved.");
    }
    // The Calandra waits for the Impressão: a printer gives it its rhythm.
    await novaMaquina(epson, { impressao_papel: "100" });
    await waitForText(page, `${epson}: salva.`);

    // 12,5 m at 25 m/h, then at 25 + 25.
    const sozinha = await horasDaCalandra();
    if (sozinha !== "30 min") throw new Error(`With one machine the Calandra takes "${sozinha}", expected 30 min`);
    await novaMaquina(segunda, { calandra: "25" });
    await waitForText(page, `${segunda}: salva.`);
    const juntas = await horasDaCalandra();
    if (juntas !== "15 min") throw new Error(`With two machines the Calandra takes "${juntas}", expected 15 min`);
  });

  await test("Unchecking the Dublagem removes it, and the histórico says so", async () => {
    await page.goto(`${BASE_URL}/parametros/maquinas`);
    await page.click(`tr[data-maquina="${calandra}"] a`);
    await page.uncheck("#trabalho_dublagem");
    if (!(await page.locator('[data-velocidade-de="dublagem"]').isDisabled())) throw new Error("The Dublagem's speed stayed open");
    await page.fill('[data-velocidade-de="calandra"]', "40");
    await page.click('button[form="maquina-form"]');
    await waitForText(page, `${calandra}: salva.`);
    await page.click(`tr[data-maquina="${calandra}"] a`);
    await waitForText(page, "Calandra 25 m/h → 40 m/h; tirou Dublagem");
    await waitForText(page, "criou com Calandra 25 m/h e Dublagem 30 m/h");
  });

  await test("To the trash and back from the Lixeira; its name stays taken there", async () => {
    await page.click('.maquina-botoes button:has-text("Mandar para a lixeira")');
    await waitForText(page, `${calandra}: foi para a lixeira.`);
    if (await page.locator(`tr[data-maquina="${calandra}"]`).count()) throw new Error("The trashed machine is still listed");
    await novaMaquina(calandra, { calandra: "10" });
    await waitForText(page, `A máquina "${calandra}" está na lixeira`);

    await page.goto(`${BASE_URL}/lixeira`);
    const item = page.locator('section[data-tipo="maquinas"] tr', { hasText: calandra });
    await item.locator('button:has-text("Restore")').click();
    await waitForText(page, `Máquina "${calandra}" restored.`);
    await page.goto(`${BASE_URL}/parametros/maquinas`);
    await page.locator(`tr[data-maquina="${calandra}"]`).waitFor();
  });

  await test("Cleanup: every machine to the trash, Ritmos typed again", async () => {
    for (const nome of [calandra, segunda, epson]) {
      await page.goto(`${BASE_URL}/parametros/maquinas`);
      await page.locator(`tr[data-maquina="${nome}"] button:has-text("Lixeira")`).click();
      await waitForText(page, `${nome}: foi para a lixeira.`);
    }
    await page.goto(`${BASE_URL}/parametros/ritmos/edit`);
    await page.locator('tr[data-ritmo="tecido:calandra"] input[name$="[por_hora]"]').waitFor();
    limparCorrida(corrida);
  });
});
