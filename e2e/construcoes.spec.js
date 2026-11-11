// Dublagem 3/5 (decided 30/10-02/11/2026): a construção is a saved dublado.
// The team opens it from Materiais, picks the superfície, then only the bases
// the network lets dub under it and only the ligantes it allows in the
// situação; the suggested price adds the empresa's layers, the ligante and
// the service per ligação; saved, it is a "Dublado" material. Dublagem 4/5:
// a corrida printed on the Oxford is dubbed into it from the pedido's item,
// its dublado charged at the final price. Dublagem 5b1a (decided
// 10/11/2026, canvas "4 · Construção em dublagens"): the form is a chave —
// a column per dublagem, a card per letra (DUB-A…), each with a material or
// an earlier letra above and below; the limit of layers is Parâmetros'.
const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");
const { BASE_URL, runSpec } = require("./support/runner");
const { uploadFileAndWait } = require("./support/upload");
const { waitForText } = require("./support/wait");

runSpec("Construções E2E Tests", async ({ page, test }) => {
  const U = Date.now() % 100000;
  const gramatura = `${U}g`;
  const nomes = {
    oxford: `Oxford-Branco-1.40 m-${gramatura}`, lona: `Lona-Branco-1.40 m-${gramatura}`,
    filme25: "Filme 25 µm-Branco-1.40 m", filme35: "Filme 35 µm-Branco-1.40 m", pu: "Filme PU 100 µm-Branco-1.40 m",
    espuma: `Espuma-Branco-1.40 m-${gramatura}`, helanca: `Helanca-Branco-1.40 m-${gramatura}`,
  };
  const ids = {};

  async function postar(url, campos) {
    return page.evaluate(async ({ url, campos }) => {
      const token = document.querySelector('meta[name="csrf-token"]')?.content || "";
      const corpo = new URLSearchParams({ authenticity_token: token });
      for (const [chave, valor] of Object.entries(campos)) [].concat(valor).forEach((v) => corpo.append(chave, v));
      const resposta = await fetch(url, { method: "POST", body: corpo });
      return resposta.ok;
    }, { url, campos });
  }

  async function buscarJson(url) {
    return page.evaluate(async (url) => (await fetch(url, { headers: { Accept: "application/json" } })).json(), url);
  }

  // A group with the roles the network expects (Dublagem 1/5's form).
  async function grupo(nome, papeis, pede) {
    await postar("/materiais/create_grupo", { "grupo_material[nome]": nome });
    const uuid = (await buscarJson(`/materiais/grupos?q=${encodeURIComponent(nome)}`)).find((g) => g.nome === nome).id;
    if (!papeis) return uuid;
    const ok = await postar(`/grupos-de-material/${uuid}`, {
      _method: "patch", "grupo_material[superficie]": papeis.superficie ? "1" : "0", "grupo_material[base]": papeis.base ? "1" : "0",
      "grupo_material[estampavel]": "nao", "pede[]": pede, "obrigatorios[]": pede,
    });
    if (!ok) throw new Error(`Couldn't set ${nome}'s roles`);
    return uuid;
  }

  // An entry of the empresa's stock, then the material's type and price.
  // busca: what finds it among many (the tecidos' gramatura is this run's).
  async function material(grupoUuid, nome, campos, tipo, preco, busca) {
    const ok = await postar("/movimentos", {
      "movimento_estoque[da_empresa]": "true", "movimento_estoque[tipo]": "entrada", "movimento_estoque[quantidade]": "30",
      "movimento_estoque[grupo_material_uuid]": grupoUuid, "movimento_estoque[cor_material_uuid]": ids.cor, "movimento_estoque[largura]": "1.40 m", ...campos,
    });
    if (!ok) throw new Error(`The entry of ${nome} failed`);
    const encontrado = (await buscarJson(`/materiais/search?q=${encodeURIComponent(busca)}`)).find((m) => m.nome_completo === nome);
    if (!encontrado) throw new Error(`${nome} wasn't registered`);
    await postar(`/materiais/${encontrado.id}`, { _method: "patch", "materia_prima[tipo]": tipo, "materia_prima[preco_metro]": preco });
    return encontrado.id;
  }

  async function opcoes(seletor) {
    return page.$$eval(`${seletor} option`, (os) => os.map((o) => o.textContent.trim()).filter((t) => !t.startsWith("—")));
  }

  // Each change asks /construcoes/montar for the form again: the answer
  // arrives before Turbo swaps it in, so wait for the new block itself (the
  // old one is marked first).
  async function montando(acao) {
    await page.locator("#construcao-montagem").evaluate((bloco) => { bloco.dataset.antigo = "1"; });
    await Promise.all([page.waitForResponse((r) => r.url().includes("/construcoes/montar") && r.ok()), acao()]);
    await page.locator("#construcao-montagem:not([data-antigo])").waitFor({ state: "attached" });
  }

  async function escolher(seletor, texto) {
    const valor = await page.$$eval(`${seletor} option`, (os, t) => os.find((o) => o.textContent.trim() === t)?.value, texto);
    if (!valor) throw new Error(`${seletor} doesn't offer ${texto}: ${await opcoes(seletor)}`);
    await montando(() => page.selectOption(seletor, valor));
  }

  await test("Setup: the network's groups, their materials with prices and the service per ligação", async () => {
    await page.goto(`${BASE_URL}/materiais`);
    ids.cor = (await buscarJson("/materiais/cores")).find((c) => c.nome === "Branco")?.id;
    if (!ids.cor) {
      await postar("/materiais/create_cor", { "cor_material[nome]": "Branco" });
      ids.cor = (await buscarJson("/materiais/cores")).find((c) => c.nome === "Branco").id;
    }
    const oxford = await grupo("Oxford");
    ids.grupoOxford = oxford;
    const lona = await grupo("Lona", { base: true }, ["gramatura"]);
    const filme = await grupo("Filme", {}, ["micras"]);
    const pu = await grupo("Filme PU", {}, ["micras"]);
    await material(oxford, nomes.oxford, { "movimento_estoque[gramatura]": gramatura }, "tecido", "20", gramatura);
    await material(lona, nomes.lona, { "movimento_estoque[gramatura]": gramatura }, "tecido", "10", gramatura);
    await material(filme, nomes.filme25, { "movimento_estoque[micras]": "25" }, "filme", "2", "Filme");
    await material(filme, nomes.filme35, { "movimento_estoque[micras]": "35" }, "filme", "3", "Filme");
    await material(pu, nomes.pu, { "movimento_estoque[micras]": "100" }, "filme", "6", "Filme");
    await page.goto(`${BASE_URL}/parametros/edit`);
    await page.fill("#empresa_preco_servico_dublagem", "4,00");
    await page.locator('form input[type="submit"][value="Save"]').click();
    await waitForText(page, "Production parameters saved.");
  });

  await test("Builds Oxford over Lona: only the bases that dub, the ligantes the situação allows, the suggested price", async () => {
    await page.goto(`${BASE_URL}/materiais`);
    await page.locator("a.materiais-construcoes-link").click();
    await page.locator(".construcoes-pagina h2").waitFor();
    await page.locator('a[href="/construcoes/new"]').click();
    await page.locator("#dublagem-0-cima").waitFor();
    // Lona is only a base: never offered on the face.
    if ((await opcoes("#dublagem-0-cima")).includes(nomes.lona)) throw new Error("Lona is offered as superfície");

    await escolher("#dublagem-0-cima", nomes.oxford);
    await escolher("#dublagem-0-baixo", nomes.lona);
    // Oxford–Lona asks for filme of 35 µm or more: the 25 µm never shows.
    const normal = await opcoes(".construcao-ligante");
    if (normal.join("|") !== nomes.filme35) throw new Error(`Normal offers ${normal}`);
    if ((await page.locator("[data-momento]").innerText()) !== "antes da Calandra") throw new Error("No 'antes da Calandra'");
    if (!(await page.locator("[data-texto]").innerText()).includes("a estampa vai aqui")) throw new Error("No 'a estampa vai aqui'");

    await montando(() => page.locator('input[name="construcao[situacao]"][value="tecido_molha"]').check());
    const molha = await opcoes(".construcao-ligante");
    if (molha.join("|") !== nomes.pu) throw new Error(`Tecido molha offers ${molha}`);
    await montando(() => page.locator('input[name="construcao[situacao]"][value=""]').check());

    await escolher(".construcao-ligante", nomes.filme35);
    const sugerido = (await page.locator("[data-sugerido]").innerText()).trim();
    if (sugerido !== "$37.00") throw new Error(`Suggested ${sugerido}; expected Oxford 20 + Lona 10 + Filme 3 + serviço 4`);
  });

  await test("Adds a pair, refuses it empty, takes it out and saves the construção as a Dublado", async () => {
    await montando(() => page.locator("button.construcao-chave-mais").click());
    await page.fill("#construcao_preco_final", "46,00");
    await page.locator(".construcao-salvar").click();
    // The flash, not the text: montar's list already said it before saving.
    await page.locator("p.alert", { hasText: "DUB-B, em cima: escolha o material" }).waitFor();

    // Both sides empty: its × takes the whole card out.
    await montando(() => page.locator('[data-dublagem="DUB-B"] button[data-acao="tirar-1-cima"]').click());
    if ((await page.locator("[data-dublagem]").count()) !== 1) throw new Error("The empty pair wasn't taken out");
    await page.locator(".construcao-salvar").click();
    const nome = `Oxford Branco / Lona Branco-1.40 m`;
    await waitForText(page, `${nome}: salva.`);

    await page.goto(`${BASE_URL}/construcoes`);
    const linha = page.locator(".construcoes-item", { hasText: nome });
    if (!(await linha.innerText()).includes("$46.00")) throw new Error(`The list shows ${await linha.innerText()}`);
    await page.goto(`${BASE_URL}/materiais`);
    const material = page.locator("tr[data-material]", { hasText: nome });
    if (!(await material.innerText()).includes("Dublado · $46.00/m")) throw new Error(`Materiais shows ${await material.innerText()}`);
    await material.locator("a.material-construcao-link").click();
    await page.locator("#construcao-montagem").waitFor();
    ids.construcao = page.url();
  });

  // The canvas's chave with this network's groups: DUB-A Oxford/Oxford and
  // DUB-B Espuma/Helanca in the 1st dublagem, DUB-C = DUB-B with Espuma in
  // the 2nd, DUB-D = DUB-A with DUB-C in the 3rd — DUB-A "segue" through
  // the 2nd. Oxford–Espuma dubs after the estampa: DUB-D after the Calandra.
  await test("Builds a chave of four dublagens: columns, letras, the 'segue', the momentos and the prices", async () => {
    const espuma = await grupo("Espuma");
    const helanca = await grupo("Helanca");
    await page.goto(`${BASE_URL}/materiais`);
    await material(espuma, nomes.espuma, { "movimento_estoque[gramatura]": gramatura }, "tecido", "18", gramatura);
    await material(helanca, nomes.helanca, { "movimento_estoque[gramatura]": gramatura }, "tecido", "9", gramatura);
    await page.goto(`${BASE_URL}/construcoes/new`);
    await escolher("#dublagem-0-cima", nomes.oxford);
    await escolher("#dublagem-0-baixo", nomes.oxford);
    await escolher(".construcao-ligante", nomes.filme35);

    await montando(() => page.locator("button.construcao-chave-mais").click());
    await escolher("#dublagem-1-cima", nomes.espuma);
    await escolher("#dublagem-1-baixo", nomes.lona);
    // A pair the network doesn't have: in red on its card (5b1b adds it from there).
    if (!(await page.locator('[data-dublagem="DUB-B"] [data-falta-rede]').innerText()).startsWith("Espuma + Lona não estão na rede.")) throw new Error("No red pair");
    await escolher("#dublagem-1-baixo", nomes.helanca);

    // "+ Juntar" adds an empty card; it sits in the 1st column until it
    // uses a letra (Q4a), so find it by its empty sides.
    async function juntar(cima, baixo) {
      await montando(() => page.locator("button[data-juntar]").click());
      const vazio = page.locator('[data-dublagem]:has(.construcao-dublagem-nome:text-is("material a escolher / material a escolher"))');
      const indice = (await vazio.locator("select.construcao-material").first().getAttribute("id")).match(/dublagem-(\d+)-/)[1];
      await escolher(`#dublagem-${indice}-cima`, cima);
      const agora = await page.locator(`[data-dublagem]:has(.construcao-ref:has-text("${cima.split(" · ")[0]}")) select.construcao-material`).getAttribute("id");
      await escolher(`#${agora}`, baixo);
    }
    await juntar("DUB-B · Espuma Branco / Helanca Branco", nomes.espuma);
    // The letras are named by column, top to bottom: once the new card holds
    // DUB-A it sits above DUB-B / Espuma in the 2nd column, which turns DUB-D.
    await juntar("DUB-A · Oxford Branco / Oxford Branco", "DUB-D · DUB-B / Espuma Branco");

    const cards = await page.locator("[data-dublagem]").evaluateAll((cs) => cs.map((c) => [c.closest("[data-coluna]").dataset.coluna, c.dataset.dublagem, c.querySelector("[data-momento]").textContent]));
    const esperado = [["1", "DUB-A", "antes da Calandra"], ["1", "DUB-B", "antes da Calandra"], ["2", "DUB-C", "antes da Calandra"], ["3", "DUB-D", "depois da Calandra"]];
    if (JSON.stringify(cards) !== JSON.stringify(esperado)) throw new Error(`The chave is ${JSON.stringify(cards)}`);
    if ((await page.locator('[data-coluna="2"] [data-segue="DUB-A"]').count()) !== 1) throw new Error("DUB-A doesn't 'segue' through the 2nd dublagem");
    if ((await page.locator('[data-dublagem="DUB-D"] [data-texto]').innerText()) !== "espera a Calandra + DUB-C · pela rede: Cola, depois da estampa") throw new Error("DUB-D's text");
    if ((await page.locator("[data-ordem]").innerText()) !== "De cima para baixo, sai da chave: Oxford Branco · Oxford Branco · Espuma Branco · Helanca Branco · Espuma Branco") throw new Error("The order");
    // Each letra's price adds the earlier one's: the last is the suggested.
    const final = (await page.locator('[data-dublagem="DUB-D"] [data-total-da-dublagem]').innerText()).trim();
    if (final !== (await page.locator("[data-sugerido]").innerText()).trim()) throw new Error(`DUB-D ${final} isn't the suggested`);
    if ((await page.locator(".construcao-chave-fios path").count()) !== 4) throw new Error("The lines between the cards");
    if (!(await page.locator("[data-produto]").innerText()).includes("feito no pedido: tem dublagem depois da Calandra")) throw new Error("No cut");

    // Without DUB-C's Espuma, DUB-C gives way to DUB-B.
    await montando(() => page.locator('[data-dublagem="DUB-C"] button[aria-label^="Tirar Espuma"]').click());
    const depois = await page.locator("[data-dublagem]").evaluateAll((cs) => cs.map((c) => `${c.dataset.dublagem}=${c.querySelector(".construcao-dublagem-nome").textContent}`));
    if (depois.join("|") !== "DUB-A=Oxford Branco / Oxford Branco|DUB-B=Espuma Branco / Helanca Branco|DUB-C=DUB-A / DUB-B") throw new Error(`After taking it out: ${depois}`);
    await page.fill("#construcao_preco_final", "90,00");
    await page.locator(".construcao-salvar").click();
    await waitForText(page, "Oxford Branco / Oxford Branco / Espuma Branco / Helanca Branco-1.40 m: salva.");
    if ((await page.locator("[data-dublagem]").count()) !== 3) throw new Error("The saved chave changed");
    ids.chave = page.url();
  });

  // Q3c: refused while an active construção has more layers, naming it.
  await test("Parâmetros refuses a most layers below an active construção", async () => {
    await page.goto(`${BASE_URL}/parametros/edit`);
    if ((await page.inputValue("#empresa_maximo_de_camadas")) !== "8") throw new Error("Doesn't start at 8");
    await page.fill("#empresa_maximo_de_camadas", "3");
    await page.locator('form input[type="submit"][value="Save"]').click();
    await page.locator("p.alert", { hasText: "o máximo de camadas não baixa para 3: Oxford Branco / Oxford Branco / Espuma Branco / Helanca Branco-1.40 m (4)" }).waitFor();
  });

  // Dublagem 5b1b (Q1b, Q2a): a pair the network doesn't have is added from
  // its card — momento and ligante group, lado any, "a confirmar" — and the
  // card is built again with it. Trashed at the end: the network stays as
  // the specs after this one expect it.
  await test("Adds a pair to the network from its card: the card gets the ligação, the rede says where it came from", async () => {
    await page.goto(`${BASE_URL}/construcoes/new`);
    await escolher("#dublagem-0-cima", nomes.oxford);
    await escolher("#dublagem-0-baixo", nomes.helanca);
    const caixa = page.locator('[data-dublagem="DUB-A"] [data-falta-rede]');
    await caixa.locator("[data-rede-momento]").selectOption("antes");
    await caixa.locator("[data-rede-ligante]").selectOption({ label: "Filme PU" });
    await montando(() => caixa.locator("button.construcao-adicionar-rede").click());

    const liga = page.locator('[data-dublagem="DUB-A"] [data-ligacao]');
    if (!(await liga.innerText()).includes("a confirmar")) throw new Error(`The card shows ${await liga.innerText()}`);
    const ligantes = await opcoes('[data-dublagem="DUB-A"] .construcao-ligante');
    if (ligantes.join("|") !== nomes.pu) throw new Error(`The card offers ${ligantes}: expected Filme PU's materials`);
    if ((await page.locator("[data-momento]").innerText()) !== "antes da Calandra") throw new Error("Not antes da Calandra");

    await liga.locator("[data-ver-na-rede]").click();
    await page.locator("[data-historico]").waitFor();
    if (!(await page.locator("[data-historico]").innerText()).includes("criou a partir da construção")) throw new Error("The histórico doesn't say where it came from");
    const marcados = await page.locator('.ligacao-confirmar input[type="checkbox"]:checked').evaluateAll((cs) => cs.map((c) => c.value).sort());
    if (marcados.join("|") !== "dubla|ligantes") throw new Error(`A confirmar: ${marcados}`);
    await page.locator("button.ligacao-lixeira").click();
    await page.locator('dialog.ligacao-dialogo button[type="submit"]:has-text("Mandar para a lixeira")').click();
    await waitForText(page, "foi para a lixeira.");
  });

  // Each change of the item's form saves and Turbo renders the pedido again,
  // swapping the body: mark the old one and wait for the new.
  async function salvarItem(acao) {
    await page.evaluate(() => { document.body.dataset.antigo = "1"; });
    await acao();
    await page.locator("body:not([data-antigo])").waitFor({ state: "attached" });
  }

  await test("Dubs a corrida's item into the construção: the dublado at its final price", async () => {
    await postar("/parametros", { _method: "patch", "empresa[preco_impressao_metro_tecido]": "15" });
    const pasta = fs.mkdtempSync(path.join(os.tmpdir(), "construcoes-"));
    const corrida = path.join(pasta, `corrida${U}.tif`);
    execFileSync("convert", ["-size", "60x60", "xc:#3a6", corrida]);
    await page.goto(`${BASE_URL}/arquivos`);
    await page.selectOption('[data-upload-target="tipo"]', "corrida");
    await uploadFileAndWait(page, corrida);
    fs.rmSync(pasta, { recursive: true, force: true });
    await page.locator(".stamp-card", { hasText: `corrida${U}` }).locator(".btn-add-to-order").click();
    const modal = page.locator("dialog.add-to-order-dialog[open]");
    await modal.locator(".add-to-order-metros").fill("2");
    const [resposta] = await Promise.all([page.waitForResponse((r) => r.url().includes("/pedidos/adicionar_item")), modal.locator('button:has-text("Adicionar")').click()]);
    ids.pedido = (await resposta.json()).pedido_uuid;

    await page.goto(`${BASE_URL}/pedidos/${ids.pedido}/resumo`);
    const oxford = await page.$$eval(".pedido-tecido-material option", (os, nome) => os.find((o) => o.textContent.startsWith(nome))?.value, nomes.oxford);
    await salvarItem(() => page.selectOption(".pedido-tecido-material", oxford));
    const nome = "Oxford Branco / Lona Branco-1.40 m";
    const construcao = await page.$$eval(".pedido-tecido-construcao option", (os, nome) => os.find((o) => o.textContent.startsWith(nome))?.value, nome);
    if (!construcao) throw new Error(`The item doesn't offer ${nome}: ${await opcoes(".pedido-tecido-construcao")}`);
    await salvarItem(() => page.selectOption(".pedido-tecido-construcao", construcao));

    const partes = await page.locator(".pedido-tecido-preco-linha").evaluateAll((linhas) => linhas.map((l) => l.dataset.parte));
    if (partes.join("|") !== "Impressão|Material dublado") throw new Error(`The item charges ${partes}`);
    const total = (await page.locator("#valores-tecido .pedido-valores-total").innerText()).trim();
    if (total !== "R$ 122,00") throw new Error(`Total ${total}; expected 2 m × (Impressão 15 + dublado 46)`);
    if (!(await page.locator("[data-dublagem]").innerText()).includes("dubla antes da estampa")) throw new Error("No 'dubla antes'");

    // Dubbed into an item, it is in use: the chave is read only.
    await page.goto(ids.construcao);
    await page.locator("[data-em-uso]").waitFor();
    if ((await page.locator("button[data-juntar], .construcao-tirar").count()) !== 0) throw new Error("The chave changes in use");
    if (!(await page.locator("#dublagem-0-cima").isDisabled())) throw new Error("Its materials change in use");
  });

  await test("Another superfície lets go of the construção, saying so", async () => {
    const outra = `${U + 1}g`;
    const outro = await material(ids.grupoOxford, `Oxford-Branco-1.40 m-${outra}`, { "movimento_estoque[gramatura]": outra }, "tecido", "20", outra);
    await page.goto(`${BASE_URL}/pedidos/${ids.pedido}/resumo`);
    await salvarItem(() => page.selectOption(".pedido-tecido-material", outro));
    await page.locator(".notice, p.notice", { hasText: "saiu do item" }).first().waitFor();
    if (await page.locator(".pedido-tecido-construcao option:checked").innerText() !== "— sem dublagem —") throw new Error("The construção stayed");
  });

  await test("Goes to the trash from its page", async () => {
    await page.goto(ids.construcao);
    // The confirm is accepted by the runner (e2e/support/runner.js).
    await page.locator(".construcao-excluir").click();
    await waitForText(page, "foi para a lixeira.");
    await page.goto(`${BASE_URL}/lixeira`);
    await page.locator('.lixeira-grupo[data-tipo="construcoes"]').waitFor();
  });

  // The chave scrolls inside its card; the page never sideways.
  await test("The form fits a phone, never scrolling sideways", async () => {
    await page.goto(ids.chave);
    await page.setViewportSize({ width: 390, height: 800 });
    const larguras = await page.evaluate(() => [document.documentElement.scrollWidth, window.innerWidth]);
    const chave = await page.locator(".construcao-chave").evaluate((c) => [c.scrollWidth, c.clientWidth]);
    await page.setViewportSize({ width: 1280, height: 800 });
    if (larguras[0] > larguras[1]) throw new Error(`The page scrolls sideways: ${larguras.join(" > ")}`);
    if (chave[0] <= chave[1]) throw new Error("The chave doesn't scroll inside its card");
  });
});
