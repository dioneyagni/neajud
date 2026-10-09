const path = require("path");
const fs = require("fs");
const os = require("os");
const { execSync } = require("child_process");
const { uploadFileAndWait } = require("./support/upload");
const { waitForQueuedTask } = require("./support/wait");
const { BASE_URL, runSpec } = require("./support/runner");
const { modeloOficial } = require("./support/catalogo");

// Etapa 2.4 (calçado, decided 09/10/2026): a pedido is charged per pair at
// the molde's price for each number (bands of the grade), written when it is
// confirmed; a number without price blocks confirming. The cost per pair
// comes from the dono's printing cost per meter and cutting cost per piece.
runSpec("Preços por par e custos", async ({ page, test }) => {
  const U = `${Date.now()}`.slice(-6);
  const nomes = { cliente: `Precos ${U}`, molde: `PR${U}`, arte: `21-PRECO${U}-29_30.tif` };
  const pasta = fs.mkdtempSync(path.join(os.tmpdir(), "neajud-precos-"));
  let moldeUuid;
  let arteUuid;
  let pedidoUuid;

  async function post(url, campos) {
    return page.evaluate(async ({ url, campos }) => {
      const token = document.querySelector('meta[name="csrf-token"]')?.content || "";
      const r = await fetch(url, { method: "POST", headers: { Accept: "application/json" }, body: new URLSearchParams({ authenticity_token: token, ...campos }) });
      return { ok: r.ok, json: await r.json().catch(() => null) };
    }, { url, campos });
  }

  async function buscar(url, chave, valor) {
    return page.evaluate(async ({ url, chave, valor }) => (await (await fetch(url)).json()).find((r) => r[chave] === valor)?.id, { url, chave, valor });
  }

  // Runs an action that reloads the page and waits for the new page: the old
  // <body> is marked, since the URL may not change (#139's CI read a 4 s flash
  // from a waitForURL that resolved at once). Not window: Turbo keeps it.
  async function recarregadaPor(acao) {
    await page.evaluate(() => { document.body.dataset.antesDaAcao = "1"; });
    await acao();
    await page.waitForFunction(() => !document.body.dataset.antesDaAcao && document.readyState !== "loading");
  }

  // Fills a band's fields (the new one, or an existing one's), submits it and
  // checks the message the molde page came back with.
  async function salvarFaixa(form, de, ate, preco, aviso) {
    await form.locator('select[name="faixa[tamanho_inicial]"]').selectOption(de);
    await form.locator('select[name="faixa[tamanho_final]"]').selectOption(ate);
    await form.locator('input[name="faixa[preco_par]"]').fill(preco);
    await recarregadaPor(() => form.locator('button[type="submit"]').click());
    if (!new URL(page.url()).pathname.endsWith(`/moldes/${moldeUuid}`)) throw new Error(`Expected the molde page, got ${page.url()}`);
    const mensagem = await page.locator(".flash-notice").first().innerText();
    if (!mensagem.includes(aviso)) throw new Error(`Expected "${aviso}", got "${mensagem}"`);
  }

  async function celula(numero, coluna) {
    return (await page.locator(`#pedido-valores tr[data-numero="${numero}"] [data-coluna="${coluna}"]`).innerText()).trim();
  }

  try {
    await test("Setup: an arte of a molde (Chinelo, DXF 29-30)", async () => {
      await page.goto(BASE_URL);
      const chinelo = await modeloOficial(page, "Chinelo");
      await post("/clients", { "client[name]": nomes.cliente, "client[responsible]": "T" });
      const clienteUuid = await buscar(`/clients/search?q=${encodeURIComponent(nomes.cliente)}`, "name", nomes.cliente);
      await post("/moldes", { "molde[sufixo]": nomes.molde, "molde[client_uuid]": clienteUuid, "molde[modelo_uuid]": chinelo.id });
      moldeUuid = await buscar(`/moldes/search?q=${encodeURIComponent(nomes.molde)}`, "sufixo", nomes.molde);

      const dxf = path.join(pasta, `PR${U}.dxf`);
      fs.copyFileSync(path.join(__dirname, "..", "spec", "fixtures", "files", "29-30.dxf"), dxf);
      await uploadFileAndWait(page, dxf);
      const corteUuid = (await page.locator(".stamp-card").filter({ hasText: `PR${U}` }).first().locator("a").first().getAttribute("href")).split("/").pop();
      await post(`/arquivos/${corteUuid}/organize`, { _method: "patch", modelo_uuid: chinelo.id, tipo_grade: "par",
        "tamanhos[0][tamanhos]": "30", "tamanhos[0][width_mm]": "150", "tamanhos[0][height_mm]": "250", "tamanhos[0][area_mm2]": "8000" });
      await post(`/arquivos/${corteUuid}/add_molde`, { molde_uuid: moldeUuid });
      await waitForQueuedTask(page, `/arquivos/${corteUuid}/preparacao_tamanhos.json`);

      // A 15,24 cm arte (60 px at 10 DPI): ten across the 1,60 m paper.
      const arte = path.join(pasta, nomes.arte);
      execSync(`convert -size 60x60 xc:teal -units PixelsPerInch -density 10 'TIFF:${arte}'`);
      await uploadFileAndWait(page, arte);
      arteUuid = (await page.locator(".stamp-card").filter({ hasText: `PRECO${U}` }).first().locator("a").first().getAttribute("href")).split("/").pop();
      await post(`/arquivos/${arteUuid}/update_molde`, { _method: "patch", molde_uuid: moldeUuid });
      await waitForQueuedTask(page, `/arquivos/${arteUuid}/busca_tamanho.json`);
    });

    await test("Parâmetros: the printing cost per meter and the cutting cost per piece, typed with a comma", async () => {
      await page.goto(`${BASE_URL}/parametros/edit`);
      await page.fill("#empresa_custo_impressao_metro", "4,50");
      await page.fill("#empresa_custo_corte_peca", "0,10");
      await recarregadaPor(() => page.click('input[type="submit"][value="Save"]'));
      if ((await page.inputValue("#empresa_custo_impressao_metro")) !== "4,50") throw new Error("The printing cost should be saved");
      if ((await page.inputValue("#empresa_custo_corte_peca")) !== "0,1") throw new Error("The cutting cost should be saved");
    });

    await test("The molde's price per pair: a band is added; one overlapping it is refused, saying why", async () => {
      await page.goto(`${BASE_URL}/moldes/${moldeUuid}`);
      await page.locator("#molde-precos").getByText("No price yet").waitFor();
      await salvarFaixa(page.locator(".molde-preco-nova"), "18", "29", "9,50", "Price 18–29 saved.");
      const faixa = page.locator('.molde-preco[data-faixa="18–29"]');
      if ((await faixa.locator('input[name="faixa[preco_par]"]').inputValue()) !== "9,50") throw new Error("The band should show its price");
      await salvarFaixa(page.locator(".molde-preco-nova"), "29", "30", "10", "29–30 overlaps the band 18–29");
      if ((await page.locator(".molde-preco").count()) !== 1) throw new Error("The overlapping band should not be saved");
    });

    await test("A number without price blocks confirming; 'abrir molde' leads to the prices; priced, the values show and it is confirmed", async () => {
      const adicionado = await post("/pedidos/adicionar_item", { arquivo_uuid: arteUuid, "grade[29]": "2", "grade[30]": "3" });
      if (!adicionado.json?.ok) throw new Error(`adicionar_item failed: ${JSON.stringify(adicionado.json)}`);
      pedidoUuid = adicionado.json.pedido_uuid;
      await page.goto(`${BASE_URL}/pedidos/${pedidoUuid}/resumo`);
      const pendencia = page.locator(".pedido-pendencia--sem_preco");
      await pendencia.filter({ hasText: "sem preço por par para 30" }).waitFor();
      if (!(await page.locator('form[action$="/confirmar"] button').isDisabled())) throw new Error("Confirmar should wait for the price");
      // A draft shows the molde's price now; the number without one, a dash.
      if ((await celula("29", "preco")) !== "R$ 9,50" || (await celula("30", "preco")) !== "—") throw new Error("The draft should show the molde's prices");

      await Promise.all([ page.waitForURL(new RegExp(`/moldes/${moldeUuid}#molde-precos$`)), pendencia.locator("a.pedido-pendencia-molde").click() ]);
      await salvarFaixa(page.locator(".molde-preco-nova"), "30", "46", "11,00", "Price 30–46 saved.");

      await page.goto(`${BASE_URL}/pedidos/${pedidoUuid}/resumo`);
      if ((await celula("30", "preco")) !== "R$ 11,00") throw new Error("The new band should price the 30");
      // 2 × 9,50 + 3 × 11,00.
      if ((await page.locator('[data-valor="valor"]').innerText()).trim() !== "R$ 52,00") throw new Error("The value should be the pairs × their price");
      if (!/^R\$ \d+,\d\d$/.test((await page.locator('[data-valor="custo"]').innerText()).trim())) throw new Error("The cost should be estimated");
      await Promise.all([ page.waitForURL(/\/pedidos$/), page.locator('form[action$="/confirmar"] button').click() ]);
      await page.goto(`${BASE_URL}/pedidos/${pedidoUuid}/resumo`);
      if ((await page.locator("h2 .badge").innerText()).trim() !== "confirmado") throw new Error("The pedido should be confirmed");
    });

    await test("A confirmed pedido keeps the price it was confirmed with when the molde's changes", async () => {
      await page.goto(`${BASE_URL}/moldes/${moldeUuid}`);
      await salvarFaixa(page.locator('.molde-preco[data-faixa="18–29"] form.molde-preco-form'), "18", "29", "20", "Price 18–29 saved.");
      await page.goto(`${BASE_URL}/pedidos/${pedidoUuid}/resumo`);
      if ((await celula("29", "preco")) !== "R$ 9,50") throw new Error("The confirmed pedido should keep R$ 9,50");
    });

    await test("The arte page shows its cost, price and margin per pair for each number", async () => {
      await page.goto(`${BASE_URL}/arquivos/${arteUuid}`);
      const linha = page.locator('#arte-custo-por-par tr[data-numero="30"]');
      if ((await linha.locator('[data-coluna="preco"]').innerText()).trim() !== "R$ 11,00") throw new Error("The arte should show the molde's price");
      if (!/^R\$ \d+,\d\d\*?$/.test((await linha.locator('[data-coluna="custo"]').innerText()).trim())) throw new Error("The arte should show its cost per pair");
    });

    // 09/10/2026: a draft's parts follow its molde (they were a photo of the
    // moment the arte was added), and the cost's "*" says what is missing.
    await test("A draft follows its molde's parts: one added shows on the item, its cost saying what it misses; removed, it goes away", async () => {
      const reforco = `Reforço ${U}`;
      await post("/pecas", { "peca[nome]": reforco });
      const rascunho = await post("/pedidos/adicionar_item", { arquivo_uuid: arteUuid, "grade[29]": "1" });
      if (!rascunho.json?.ok) throw new Error(`adicionar_item failed: ${JSON.stringify(rascunho.json)}`);
      const resumo = `${BASE_URL}/pedidos/${rascunho.json.pedido_uuid}/resumo`;

      await page.goto(`${BASE_URL}/moldes/${moldeUuid}`);
      await page.locator("#peca_uuid_parte").selectOption({ label: reforco });
      await recarregadaPor(() => page.locator("form.molde-adicionar-parte button[type=submit]").click());
      await page.goto(resumo);
      await page.locator(`.pedido-peca[data-parte="${reforco}"]`).first().waitFor();
      const faltas = await page.locator("#pedido-valores .custo-faltas").innerText();
      if (!faltas.includes(`${reforco} (29): no organized corte serves it`)) throw new Error(`The "*" should name the part: ${faltas}`);

      await page.goto(`${BASE_URL}/moldes/${moldeUuid}`);
      await recarregadaPor(() => page.locator(`.molde-peca-row[data-parte="${reforco}"] button`, { hasText: "Remove" }).click());
      await page.goto(resumo);
      await page.locator(".pedido-item").first().waitFor();
      // The part left the molde, so the draft no longer orders it.
      if ((await page.locator(`.pedido-peca[data-parte="${reforco}"]`).count()) !== 0) throw new Error("The removed part should leave the draft");
    });
  } finally {
    fs.rmSync(pasta, { recursive: true, force: true });
  }
});
