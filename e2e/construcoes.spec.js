// Dublagem 3/5 (decided 30/10-02/11/2026): a construção is a saved dublado.
// The team opens it from Materiais, picks the superfície, then only the bases
// the network lets dub under it and only the ligantes it allows in the
// situação; the suggested price adds the empresa's layers, the ligante and
// the service per ligação; saved, it is a "Dublado" material. Dublagem 4/5:
// a corrida printed on the Oxford is dubbed into it from the pedido's item,
// its dublado charged at the final price.
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
    await page.locator("#camada-0-material").waitFor();
    // Lona is only a base: never offered on the face.
    if ((await opcoes("#camada-0-material")).includes(nomes.lona)) throw new Error("Lona is offered as superfície");

    await escolher("#camada-0-material", nomes.oxford);
    await escolher("#camada-1-material", nomes.lona);
    // Oxford–Lona asks for filme of 35 µm or more: the 25 µm never shows.
    const normal = await opcoes(".construcao-ligante");
    if (normal.join("|") !== nomes.filme35) throw new Error(`Normal offers ${normal}`);
    if (!(await page.locator("[data-ligacao]").innerText()).includes("dubla antes da estampa")) throw new Error("No 'dubla antes'");

    await montando(() => page.locator('input[name="construcao[situacao]"][value="tecido_molha"]').check());
    const molha = await opcoes(".construcao-ligante");
    if (molha.join("|") !== nomes.pu) throw new Error(`Tecido molha offers ${molha}`);
    await montando(() => page.locator('input[name="construcao[situacao]"][value=""]').check());

    await escolher(".construcao-ligante", nomes.filme35);
    const sugerido = (await page.locator("[data-sugerido]").innerText()).trim();
    if (sugerido !== "$37.00") throw new Error(`Suggested ${sugerido}; expected Oxford 20 + Lona 10 + Filme 3 + serviço 4`);
  });

  await test("Adds a layer, refuses it empty, removes it and saves the construção as a Dublado", async () => {
    await montando(() => page.locator('button[data-acao="adicionar"]').click());
    await page.fill("#construcao_preco_final", "46,00");
    await page.locator(".construcao-salvar").click();
    // The flash, not the text: montar's list already said it before saving.
    await page.locator("p.alert", { hasText: "camada 3: escolha o material" }).waitFor();

    await montando(() => page.locator('button[data-acao="remover-3"]').click());
    if ((await page.locator(".construcao-item").count()) !== 2) throw new Error("The third layer wasn't removed");
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

  await test("The form fits a phone, never scrolling sideways", async () => {
    await page.goto(`${BASE_URL}/construcoes/new`);
    await escolher("#camada-0-material", nomes.oxford);
    await page.setViewportSize({ width: 390, height: 800 });
    const larguras = await page.evaluate(() => [document.documentElement.scrollWidth, window.innerWidth]);
    await page.setViewportSize({ width: 1280, height: 800 });
    if (larguras[0] > larguras[1]) throw new Error(`The page scrolls sideways: ${larguras.join(" > ")}`);
  });
});
