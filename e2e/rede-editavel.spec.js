// Rede editável 2/2a (decided 09-10/11/2026, canvas "Rede editável — C"):
// the team edits the dublagem network, one page per ligação — the form,
// where it is used and its histórico. "+ Ligação" creates one; a ligação
// goes to the trash (confirmed on the page) and back from the Lixeira. A
// construção in use keeps what it was made with and says "a rede mudou".
// Without "Editar a rede de dublagens" the page is read only.
//
// It changes Oxford com Lona and sets it back at the end, so the specs
// after it find the initial network.
const { E2E_USUARIO, entrar, entrarComoNovoUsuario } = require("./support/sessao");
const { BASE_URL, runSpec } = require("./support/runner");
const { waitForText } = require("./support/wait");
const { prepararDublagem, salvarConstrucao, colocarEmUso } = require("./support/dublagem");

runSpec("Rede editável E2E Tests", async ({ page, test }) => {
  const U = Date.now() % 100000;
  const ids = {};
  const operador = { nome: `Produção ${U}`, email: `producao${U}@neajud.test`, provisoria: "provisoria-e2e-1", senha: "senha-producao-e2e-1" };

  async function texto(seletor) {
    return (await page.locator(seletor).innerText()).replace(/\s+/g, " ");
  }

  async function abrirLigacao(grupoDeCima, outro) {
    await page.goto(`${BASE_URL}/rede-de-dublagens`);
    await page.locator(`.rede-grupo[data-grupo="${grupoDeCima}"] .rede-ligacao[data-par="${grupoDeCima}–${outro}"] a`).click();
    await page.locator(".ligacao-pagina h2").waitFor();
  }

  async function salvar(aviso) {
    await page.locator('#ligacao-form button[type="submit"]').click();
    await waitForText(page, aviso);
  }

  await test("Setup: Oxford over Lona with Filme 35 µm, a construção whose dublado is in stock (in use)", async () => {
    const dublagem = await prepararDublagem(page, `${U}g`);
    ids.construcao = await salvarConstrucao(page, dublagem, { lado: "trama", situacao: "" });
    await colocarEmUso(page, ids.construcao);
  });

  await test("+ Ligação creates Lona com EVA with two ligantes, its histórico saying 'criou'", async () => {
    await page.goto(`${BASE_URL}/rede-de-dublagens`);
    await page.locator('a:has-text("+ Ligação")').click();
    await page.locator("#ligacao_grupo_a_uuid").waitFor();
    await page.selectOption("#ligacao_grupo_a_uuid", { label: "Lona" });
    await page.selectOption("#ligacao_grupo_b_uuid", { label: "EVA" });
    await page.locator('label:has-text("dubla depois")').click();
    await page.selectOption('[data-ligantes][data-nome="ligacao[ligantes]"] select', { label: "Cola" });
    await page.locator('[data-nome="ligacao[ligantes]"] button:has-text("+ ligante")').click();
    const segunda = page.locator('[data-nome="ligacao[ligantes]"] .ligacao-ligante').nth(1);
    await segunda.locator("select").selectOption({ label: "Filme" });
    await segunda.locator("input").fill("25 ou 35");
    await salvar("Lona com EVA: salva.");
    if ((await texto("[data-historico]")).indexOf("criou") < 0) throw new Error("The histórico doesn't say 'criou'");

    await page.goto(`${BASE_URL}/rede-de-dublagens`);
    const linha = await texto('.rede-ligacao[data-par="Lona–EVA"]');
    if (!linha.includes("Cola ou Filme 25 ou 35 µm") || !linha.includes("dubla depois")) throw new Error(`The rede shows ${linha}`);
  });

  // Decision 2: the pair has no order, so EVA com Lona is the same one.
  await test("The same pair in the other order is refused, saying it is in the network", async () => {
    await page.goto(`${BASE_URL}/rede-de-dublagens/ligacoes/new`);
    await page.selectOption("#ligacao_grupo_a_uuid", { label: "EVA" });
    await page.selectOption("#ligacao_grupo_b_uuid", { label: "Lona" });
    await page.selectOption('[data-nome="ligacao[ligantes]"] select', { label: "Cola" });
    await page.locator('#ligacao-form button[type="submit"]').click();
    await waitForText(page, "EVA com Lona já está na rede");
  });

  await test("Editing Oxford com Lona: before → after, a situação back to the usual ligantes, one line in the histórico", async () => {
    await abrirLigacao("Oxford", "Lona");
    if ((await page.locator("[data-grupo-a]").innerText()) !== "Oxford") throw new Error("An existing ligação's groups aren't plain text");
    await page.locator('label:has-text("dubla depois")').click();
    await page.locator('[data-situacao="tecido_molha"] button:has-text("voltar aos de cima")').click();
    await page.locator('[data-situacao="vai_frequencia"] button:has-text("mudar")').click();
    await page.locator('[data-situacao="vai_frequencia"] .ligacao-ligante select').selectOption({ label: "Filme PU" });
    await salvar("Oxford com Lona: salva.");
    const historico = await texto("[data-historico]");
    const esperado = "dubla antes → depois; Tecido molha: Filme PU → os de cima; Vai frequência: os de cima → Filme PU";
    if (!historico.includes(`${E2E_USUARIO.nome} · ${esperado}`)) throw new Error(`The histórico says ${historico}`);
    const uso = await texto("[data-uso]");
    if (!uso.includes("em uso") || !uso.includes("a rede mudou")) throw new Error(`"Onde ela é usada" says ${uso}`);
  });

  // Q3a/Q6a: in use, the construção keeps "antes" and says the network changed.
  await test("The construção in use keeps what it was made with and says 'a rede mudou', linking to the ligação", async () => {
    await page.goto(`${BASE_URL}/construcoes/${ids.construcao}/edit`);
    const aviso = await texto("[data-rede-mudou]");
    if (!aviso.includes("a rede mudou: guardou dubla antes; a rede agora diz depois")) throw new Error(`The construção says ${aviso}`);
    await page.locator('[data-rede-mudou] a:has-text("ver na rede")').click();
    await page.locator(".ligacao-pagina h2:has-text('Oxford com Lona')").waitFor();
    await page.goto(`${BASE_URL}/construcoes`);
    if ((await page.locator(`.construcoes-item:has(a[href="/construcoes/${ids.construcao}/edit"]) .rede-chip--mudou`).count()) !== 1) {
      throw new Error("The list doesn't mark the construção 'a rede mudou'");
    }
  });

  await test("The trash asks on the page: Cancel keeps it, confirming takes it out of the network, the Lixeira restores it", async () => {
    await abrirLigacao("Lona", "EVA");
    await page.locator('button.ligacao-lixeira').click();
    const dialogo = page.locator("dialog.ligacao-dialogo");
    await dialogo.waitFor();
    const caixa = await dialogo.boundingBox();
    const tela = page.viewportSize();
    const centro = [caixa.x + caixa.width / 2 - tela.width / 2, caixa.y + caixa.height / 2 - tela.height / 2];
    if (centro.some((d) => Math.abs(d) > 2)) throw new Error(`The dialog isn't centered: off by ${centro}`);
    if (!(await dialogo.innerText()).includes("Nenhuma construção usa esta ligação")) throw new Error("The dialog doesn't say who uses it");
    await dialogo.locator('button:has-text("Cancelar")').click();
    await dialogo.waitFor({ state: "hidden" });

    await page.locator('button.ligacao-lixeira').click();
    await dialogo.locator('button[type="submit"]:has-text("Mandar para a lixeira")').click();
    await waitForText(page, "Lona com EVA: foi para a lixeira.");
    if ((await page.locator('.rede-ligacao[data-par="Lona–EVA"]').count()) !== 0) throw new Error("A trashed ligação is still in the network");

    await page.goto(`${BASE_URL}/lixeira`);
    const linha = page.locator('[data-tipo="ligacoes_dublagem"] tr:has-text("Lona com EVA")');
    await linha.locator('button:has-text("Restore")').click();
    await waitForText(page, "restored");
    await page.goto(`${BASE_URL}/rede-de-dublagens`);
    await page.locator('.rede-ligacao[data-par="Lona–EVA"]').waitFor();
  });

  await test("The ligação's page fits a phone, never scrolling sideways", async () => {
    await abrirLigacao("Oxford", "Lona");
    await page.setViewportSize({ width: 390, height: 800 });
    const larguras = await page.evaluate(() => [document.documentElement.scrollWidth, window.innerWidth]);
    await page.setViewportSize({ width: 1280, height: 800 });
    if (larguras[0] > larguras[1]) throw new Error(`The page scrolls sideways: ${larguras.join(" > ")}`);
  });

  // Q7a: Produção sees the estoque but hasn't the action.
  await test("Without 'Editar a rede de dublagens' the ligação's page is read only, with no + Ligação", async () => {
    await entrarComoNovoUsuario(page, BASE_URL, operador, "Produção");

    await page.goto(`${BASE_URL}/rede-de-dublagens`);
    if ((await page.locator('a:has-text("+ Ligação")').count()) !== 0) throw new Error("+ Ligação shows without the action");
    await abrirLigacao("Oxford", "Lona");
    // isDisabled() only reads form controls, not a fieldset.
    if ((await page.locator("fieldset.ligacao-campos").getAttribute("disabled")) === null) throw new Error("The form can be edited without the action");
    if (!(await page.locator('#ligacao-form select[name="ligacao[lado]"]').isDisabled())) throw new Error("The lado can be changed without the action");
    if ((await page.locator('#ligacao-form button[type="submit"]').count()) !== 0) throw new Error("Salvar shows without the action");
  });

  await test("Cleanup: the dono sets Oxford com Lona back as the initial network has it", async () => {
    await page.click('.header-user button:has-text("Sign out")');
    await page.waitForURL("**/session/new");
    await entrar(page, BASE_URL);
    await abrirLigacao("Oxford", "Lona");
    await page.locator('label:has-text("dubla antes")').click();
    await page.locator('[data-situacao="vai_frequencia"] button:has-text("voltar aos de cima")').click();
    await page.locator('[data-situacao="tecido_molha"] button:has-text("mudar")').click();
    await page.locator('[data-situacao="tecido_molha"] .ligacao-ligante select').selectOption({ label: "Filme PU" });
    await salvar("Oxford com Lona: salva.");
  });
});
