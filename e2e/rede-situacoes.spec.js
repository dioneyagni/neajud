// Rede editável 2/2b (decided 10/11/2026, canvas "2/2b · Rede: bloco
// Situações"): the rede's Situações card. "+ Situação" adds one that changes
// no ligação yet — the construção says so (Q3a); renaming happens in its own
// row, renames the construções not in use and keeps the ones in use (Q1b);
// the histórico is in the card, closed (Q2a). No trash on purpose. Without
// "Editar a rede de dublagens" the card is read only.
//
// It only adds its own situação, so the initial ones stay as they are for
// the specs after it.
const { entrar, entrarComoNovoUsuario } = require("./support/sessao");
const { BASE_URL, runSpec } = require("./support/runner");
const { waitForText } = require("./support/wait");
const { prepararDublagem, salvarConstrucao, colocarEmUso } = require("./support/dublagem");

runSpec("Rede Situações E2E Tests", async ({ page, test }) => {
  const U = Date.now() % 100000;
  const nome = `Úmido ${U}`;
  const novoNome = `Encharcado ${U}`;
  const ids = {};
  const operador = { nome: `Leitura ${U}`, email: `leitura${U}@neajud.test`, provisoria: "provisoria-e2e-2", senha: "senha-leitura-e2e-2" };

  async function texto(seletor) {
    return (await page.locator(seletor).innerText()).replace(/\s+/g, " ");
  }

  async function nomeDaConstrucao(uuid) {
    await page.goto(`${BASE_URL}/construcoes/${uuid}/edit`);
    return page.locator("h2").first().innerText();
  }

  const linha = () => page.locator(`[data-situacao-linha="${ids.chave}"]`);

  await test("+ Situação adds one that changes no ligação yet: its row, its column and the histórico's line", async () => {
    await page.goto(`${BASE_URL}/rede-de-dublagens`);
    await page.fill("#situacao_nome_nova", nome);
    await page.locator('.rede-situacao-nova button:has-text("+ Situação")').click();
    await waitForText(page, `Situação ${nome}: criada.`);
    ids.chave = await page.locator(`.rede-situacao:has([data-nome]:text-is("${nome}"))`).getAttribute("data-situacao-linha");
    if (ids.chave !== `umido_${U}`) throw new Error(`The chave is ${ids.chave}`);
    const uso = await texto(`[data-situacao-linha="${ids.chave}"] [data-uso]`);
    if (uso !== "ainda não muda nenhuma ligação · 0 construções") throw new Error(`The row says ${uso}`);
    if ((await page.locator(`.rede-tabela th:text-is("${nome}")`).count()) === 0) throw new Error("The tables have no column for it");

    // Q2a: closed until opened.
    if (await page.locator("[data-historico]").isVisible()) throw new Error("The histórico starts open");
    await page.locator('.rede-situacoes-historico summary').click();
    if (!(await texto("[data-historico]")).includes(`criou ${nome}`)) throw new Error("The histórico doesn't say 'criou'");
  });

  await test("A repeated name is refused, saying which", async () => {
    await page.fill("#situacao_nome_nova", nome.toUpperCase());
    await page.locator('.rede-situacao-nova button:has-text("+ Situação")').click();
    await waitForText(page, `${nome.toUpperCase()} já é uma situação da rede`);
  });

  await test("The construção's situação picker shows it, saying it changes no ligação yet", async () => {
    await page.goto(`${BASE_URL}/construcoes/new`);
    const opcao = page.locator(`label.construcao-pill:has(input[value="${ids.chave}"])`);
    if ((await opcao.locator("[data-nao-muda]").innerText()) !== "ainda não muda nenhuma ligação") throw new Error("No note on the new situação");
    // The initial ones change ligações: no note there.
    if ((await page.locator('label.construcao-pill:has(input[value="tecido_molha"]) [data-nao-muda]').count()) !== 0) throw new Error("Tecido molha has the note");
  });

  await test("Setup: two construções with it, one in use", async () => {
    const dublagem = await prepararDublagem(page, `${U}s`);
    ids.semUso = await salvarConstrucao(page, dublagem, { lado: "trama", situacao: ids.chave });
    ids.emUso = await salvarConstrucao(page, dublagem, { lado: "avesso", situacao: ids.chave });
    await colocarEmUso(page, ids.emUso);
    ids.nomeEmUso = await nomeDaConstrucao(ids.emUso);
    if (!ids.nomeEmUso.endsWith(`(${nome})`)) throw new Error(`The dublado is named ${ids.nomeEmUso}`);
  });

  await test("Renaming in its row: Cancelar keeps the name, Salvar renames the construção not in use and keeps the one in use", async () => {
    await page.goto(`${BASE_URL}/rede-de-dublagens`);
    if ((await texto(`[data-situacao-linha="${ids.chave}"] [data-uso]`)) !== "ainda não muda nenhuma ligação · 2 construções") throw new Error("The row doesn't count the construções");
    await linha().locator('button:has-text("Renomear")').click();
    const campo = linha().locator('input[name="situacao[nome]"]');
    await campo.fill("Outro qualquer");
    await linha().locator('button:has-text("Cancelar")').click();
    if ((await linha().locator("[data-nome]").innerText()) !== nome) throw new Error("Cancelar didn't keep the name");
    if (await campo.isVisible()) throw new Error("The form stays open after Cancelar");

    await linha().locator('button:has-text("Renomear")').click();
    if ((await campo.inputValue()) !== nome) throw new Error("Cancelar kept what was typed");
    await campo.fill(novoNome);
    await linha().locator('button:has-text("Salvar")').click();
    await waitForText(page, `Situação ${novoNome}: salva.`);
    await page.locator('.rede-situacoes-historico summary').click();
    const historico = await texto("[data-historico]");
    if (!historico.includes(`renomeou ${nome} → ${novoNome}; 1 construção renomeada`)) throw new Error(`The histórico says ${historico}`);

    if (!(await nomeDaConstrucao(ids.semUso)).endsWith(`(${novoNome})`)) throw new Error("The construção not in use kept the old name");
    if ((await nomeDaConstrucao(ids.emUso)) !== ids.nomeEmUso) throw new Error("The construção in use was renamed");
  });

  await test("The rede's page with the card fits a phone, never scrolling sideways", async () => {
    await page.goto(`${BASE_URL}/rede-de-dublagens`);
    await page.setViewportSize({ width: 390, height: 800 });
    await linha().locator('button:has-text("Renomear")').click();
    const larguras = await page.evaluate(() => [document.documentElement.scrollWidth, window.innerWidth]);
    await page.setViewportSize({ width: 1280, height: 800 });
    if (larguras[0] > larguras[1]) throw new Error(`The page scrolls sideways: ${larguras.join(" > ")}`);
  });

  // Q7a of 2/2a: Produção sees the estoque but hasn't the action.
  await test("Without 'Editar a rede de dublagens' the card is read only", async () => {
    await entrarComoNovoUsuario(page, BASE_URL, operador, "Produção");
    await page.goto(`${BASE_URL}/rede-de-dublagens`);
    await linha().waitFor();
    if ((await page.locator("#situacoes form, #situacoes button").count()) !== 0) throw new Error("The card can be changed without the action");

    await page.click('.header-user button:has-text("Sign out")');
    await page.waitForURL("**/session/new");
    await entrar(page, BASE_URL);
  });
});
