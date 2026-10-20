const path = require("path");
const fs = require("fs");
const os = require("os");
const { execSync } = require("child_process");
const { uploadFileAndWait } = require("./support/upload");
const { waitForQueuedTask } = require("./support/wait");
const { BASE_URL, runSpec } = require("./support/runner");
const { modeloOficial } = require("./support/catalogo");

// Etapa 2.3d1 (decided 19/10/2026): whose fabric a pedido takes cascades
// cliente → molde → pedido, each blank inheriting the level above; the
// pedido prints on the empresa's default paper (or DTF film) unless the team
// picks another — the film is a material now, chosen in Parâmetros.
runSpec("Materiais do pedido", async ({ page, test }) => {
  const U = `${Date.now()}`.slice(-6);
  const nomes = { cliente: `MatPed ${U}`, molde: `MP${U}`, arte: `31-MATPED${U}.tif`, papel: `PapelMP${U}`, filme: `FilmeMP${U}` };
  const pasta = fs.mkdtempSync(path.join(os.tmpdir(), "neajud-materiais-"));
  let clienteUuid;
  let moldeUuid;
  let pedidoUuid;
  const materiais = {};

  async function enviar(url, campos, metodo = "POST") {
    return page.evaluate(async ({ url, campos, metodo }) => {
      const token = document.querySelector('meta[name="csrf-token"]')?.content || "";
      const r = await fetch(url, { method: metodo, headers: { Accept: "application/json" }, body: new URLSearchParams({ authenticity_token: token, ...campos }), redirect: "manual" });
      return { ok: r.ok || r.type === "opaqueredirect", json: await r.json().catch(() => null) };
    }, { url, campos, metodo });
  }

  async function buscar(url, chave, valor) {
    return page.evaluate(async ({ url, chave, valor }) => (await (await fetch(url)).json()).find((r) => r[chave] === valor)?.id, { url, chave, valor });
  }

  // A material of the empresa's stock, then its type set on the Materials page's endpoint.
  async function material(grupo, largura, tipo) {
    await page.evaluate(async ({ grupo }) => {
      const token = document.querySelector('meta[name="csrf-token"]')?.content || "";
      const form = new FormData();
      form.append("grupo_material[nome]", grupo);
      await fetch("/materiais/create_grupo", { method: "POST", headers: { "X-CSRF-Token": token }, body: form, redirect: "manual" });
    }, { grupo });
    const grupoUuid = await buscar(`/materiais/grupos?q=${encodeURIComponent(grupo)}`, "nome", grupo);
    const corUuid = await page.evaluate(async () => (await (await fetch("/materiais/cores")).json())[0]?.id);
    await enviar("/materiais", { "movimento_estoque[da_empresa]": "1", "movimento_estoque[tipo]": "entrada", "movimento_estoque[grupo_material_uuid]": grupoUuid,
      "movimento_estoque[cor_material_uuid]": corUuid, "movimento_estoque[largura]": largura, "movimento_estoque[gramatura]": "1g", "movimento_estoque[quantidade]": "10" });
    const uuid = await page.evaluate(async (grupo) => (await (await fetch(`/materiais/search?q=${encodeURIComponent(grupo)}`)).json())[0]?.id, grupo);
    await enviar(`/materiais/${uuid}`, { _method: "patch", "materia_prima[tipo]": tipo });
    return uuid;
  }

  // Runs an action that reloads the page (an auto-submitted select) and
  // waits for the new page: the old <body> is marked.
  async function recarregadaPor(acao) {
    await page.evaluate(() => { document.body.dataset.antesDaAcao = "1"; });
    await acao();
    await page.waitForFunction(() => !document.body.dataset.antesDaAcao && document.readyState !== "loading");
  }

  async function resumo(campo) {
    return (await page.locator(`[data-resumo="${campo}"]`).innerText()).trim();
  }

  async function esperarNoPedido(campo, esperado) {
    await page.goto(`${BASE_URL}/pedidos/${pedidoUuid}/resumo`);
    const atual = await resumo(campo);
    if (atual !== esperado) throw new Error(`Expected ${campo} "${esperado}", got "${atual}"`);
  }

  try {
    await test("Setup: a client, a molde, an arte of it in a draft, a paper and a DTF film", async () => {
      await page.goto(BASE_URL);
      const chinelo = await modeloOficial(page, "Chinelo");
      await enviar("/clients", { "client[name]": nomes.cliente, "client[responsible]": "T" });
      clienteUuid = await buscar(`/clients/search?q=${encodeURIComponent(nomes.cliente)}`, "name", nomes.cliente);
      await enviar("/moldes", { "molde[sufixo]": nomes.molde, "molde[client_uuid]": clienteUuid, "molde[modelo_uuid]": chinelo.id });
      moldeUuid = await buscar(`/moldes/search?q=${encodeURIComponent(nomes.molde)}`, "sufixo", nomes.molde);

      const arte = path.join(pasta, nomes.arte);
      execSync(`convert -size 60x60 xc:olive -units PixelsPerInch -density 10 'TIFF:${arte}'`);
      await uploadFileAndWait(page, arte);
      const arteUuid = (await page.locator(".stamp-card").filter({ hasText: `MATPED${U}` }).first().locator("a").first().getAttribute("href")).split("/").pop();
      await enviar(`/arquivos/${arteUuid}/update_molde`, { _method: "patch", molde_uuid: moldeUuid });
      await waitForQueuedTask(page, `/arquivos/${arteUuid}/busca_tamanho.json`);
      const adicionado = await enviar("/pedidos/adicionar_item", { arquivo_uuid: arteUuid, "grade[30]": "2" });
      if (!adicionado.json?.ok) throw new Error(`adicionar_item failed: ${JSON.stringify(adicionado.json)}`);
      pedidoUuid = adicionado.json.pedido_uuid;

      materiais.papel = await material(nomes.papel, "1,10 m", "papel");
      materiais.filme = await material(nomes.filme, "60 cm", "filme_dtf");
      await esperarNoPedido("dono-tecido", "Do cliente (padrão)");
    });

    await test("The client's page sets whose fabric; the pedido inherits it and says from where", async () => {
      await page.goto(`${BASE_URL}/clients/${clienteUuid}`);
      await recarregadaPor(() => page.selectOption("#cliente-dono-tecido", "empresa"));
      if ((await page.inputValue("#cliente-dono-tecido")) !== "empresa") throw new Error("The client's choice should be saved");
      await esperarNoPedido("dono-tecido", "Da empresa (do cadastro do cliente)");
    });

    await test("The molde's page overrides the client's, offering to inherit it", async () => {
      await page.goto(`${BASE_URL}/moldes/${moldeUuid}`);
      const herdar = (await page.locator("#molde-dono-tecido option").first().innerText()).trim();
      if (herdar !== "Herdar do cliente: da empresa") throw new Error(`The blank option should say what it inherits, got "${herdar}"`);
      await recarregadaPor(() => page.selectOption("#molde-dono-tecido", "cliente"));
      await esperarNoPedido("dono-tecido", "Do cliente (do molde)");
    });

    await test("The pedido's panel overrides both and picks its paper; blank goes back to inheriting and to the default", async () => {
      const opcoes = await page.locator("#pedido-dono-tecido option").allInnerTexts();
      if (opcoes[0].trim() !== "Herdar: do cliente (do molde)") throw new Error(`The blank option should say what the pedido inherits, got "${opcoes[0]}"`);
      await recarregadaPor(() => page.selectOption("#pedido-dono-tecido", "empresa"));
      if ((await resumo("dono-tecido")) !== "Da empresa (escolhido no pedido)") throw new Error("The pedido's choice should win");

      await recarregadaPor(() => page.selectOption("#pedido-material-impressao", materiais.papel));
      if (!(await resumo("material-impressao")).startsWith(nomes.papel)) throw new Error("The pedido should print on the paper picked");
      // A film is no paper: a calçado pedido never offers it.
      const filmes = await page.locator(`#pedido-material-impressao option[value="${materiais.filme}"]`).count();
      if (filmes !== 0) throw new Error("A calçado pedido should not offer the DTF film");

      await recarregadaPor(() => page.selectOption("#pedido-dono-tecido", ""));
      await recarregadaPor(() => page.selectOption("#pedido-material-impressao", ""));
      if ((await resumo("dono-tecido")) !== "Do cliente (do molde)") throw new Error("A blank choice should inherit again");
      if ((await resumo("material-impressao")).startsWith(nomes.papel)) throw new Error("A blank paper should go back to the default");
    });

    // The film's width replaces the typed one; set back so later fits stay at 600 mm.
    await test("Parâmetros: the default DTF film is a material, its width the one left for the etiquetas", async () => {
      await page.goto(`${BASE_URL}/parametros/edit`);
      await page.selectOption("#empresa_filme_dtf_padrao_uuid", materiais.filme);
      await recarregadaPor(() => page.click('input[type="submit"][value="Save"]'));
      if ((await page.inputValue("#empresa_filme_dtf_padrao_uuid")) !== materiais.filme) throw new Error("The default film should be saved");
      if (!(await page.locator(".parametros-dtf-util").innerText()).startsWith("570 mm")) throw new Error("The margins should come off the film's width");
      await page.selectOption("#empresa_filme_dtf_padrao_uuid", "");
      await recarregadaPor(() => page.click('input[type="submit"][value="Save"]'));
    });
  } finally {
    fs.rmSync(pasta, { recursive: true, force: true });
  }
});
