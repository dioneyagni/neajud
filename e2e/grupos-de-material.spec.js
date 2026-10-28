// Dublagem 1/5 (decided 27/10/2026): the material groups as families. The
// team marks on a group's page what its materials require (Espuma: densidade)
// and whether it prints; the stock entry then shows that field and refuses a
// new material without it. A tecido pedido offers only what prints — the
// card's modal and the item's select — and warns of a group's ressalva.
const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");
const { BASE_URL, runSpec } = require("./support/runner");
const { uploadFileAndWait } = require("./support/upload");
const { waitForText } = require("./support/wait");

runSpec("Grupos de material E2E Tests", async ({ page, test }) => {
  const U = Date.now();
  const grupos = { espuma: `Espuma${U}`, tnt: `TNT${U}`, telinha: `Telinha${U}` };
  const nomes = { cliente: `Familias ${U}`, corrida: `familia${U}` };
  const ids = {};
  const pasta = fs.mkdtempSync(path.join(os.tmpdir(), "grupos-de-material-"));

  async function postar(url, campos) {
    return page.evaluate(async ({ url, campos }) => {
      const token = document.querySelector('meta[name="csrf-token"]')?.content || "";
      const resposta = await fetch(url, { method: "POST", body: new URLSearchParams({ authenticity_token: token, ...campos }) });
      return resposta.ok ? resposta.url : null;
    }, { url, campos });
  }

  async function buscarJson(url) {
    return page.evaluate(async (url) => (await fetch(url, { headers: { Accept: "application/json" } })).json(), url);
  }

  // Opens the group from the Materiais page's "Grupos", as the team would.
  async function abrirGrupo(nome) {
    await page.goto(`${BASE_URL}/materiais`);
    await page.locator(".materiais-grupos-link").click();
    await page.locator(`.grupos-item[data-grupo="${nome}"]`).click();
    await page.locator(`.grupos-item[data-grupo="${nome}"][aria-current="page"]`).waitFor();
  }

  async function salvarGrupo(nome) {
    await page.locator('.grupo-form input[type="submit"]').click();
    await waitForText(page, `${nome}: salvo.`);
  }

  // An entry of the empresa's stock, the group's own fields filled.
  async function entrada(grupo, campos = {}) {
    const resposta = await postar("/movimentos", {
      "movimento_estoque[da_empresa]": "true", "movimento_estoque[tipo]": "entrada", "movimento_estoque[quantidade]": "30",
      "movimento_estoque[grupo_material_uuid]": ids[grupo], "movimento_estoque[cor_material_uuid]": ids.cor,
      "movimento_estoque[largura]": "1.50", "movimento_estoque[gramatura]": "90g", ...campos,
    });
    if (!resposta) throw new Error(`The entry of ${grupo} failed`);
  }

  async function material(grupo) {
    return (await buscarJson(`/materiais/search?q=${encodeURIComponent(grupo)}`))[0];
  }

  await test("Setup: three groups, a color and a client", async () => {
    await page.goto(`${BASE_URL}/materiais`);
    for (const nome of Object.values(grupos)) await postar("/materiais/create_grupo", { "grupo_material[nome]": nome });
    const todos = await buscarJson(`/materiais/grupos?q=${U}`);
    for (const [chave, nome] of Object.entries(grupos)) ids[chave] = todos.find((g) => g.nome === nome)?.id;
    if (Object.keys(grupos).some((chave) => !ids[chave])) throw new Error(`Groups missing: ${JSON.stringify(todos)}`);
    ids.cor = (await buscarJson("/materiais/cores")).find((c) => c.nome === "Branco")?.id || (await postar("/materiais/create_cor", { "cor_material[nome]": "Branco" }), (await buscarJson("/materiais/cores")).find((c) => c.nome === "Branco").id);
    if (!(await postar("/clients", { "client[name]": nomes.cliente, "client[responsible]": "T" }))) throw new Error("Couldn't create the client");
    ids.cliente = (await buscarJson(`/clients/search?q=${encodeURIComponent(nomes.cliente)}`)).find((c) => c.name === nomes.cliente).id;
  });

  await test("A group's page sets its roles, printing and required attributes", async () => {
    await abrirGrupo(grupos.espuma);
    await page.uncheck("#grupo_material_superficie");
    await page.check("#grupo_material_base");
    await page.check("#grupo_material_estampavel_nao");
    await page.uncheck('input[name="pede[]"][value="gramatura"]');
    await page.uncheck('input[name="obrigatorios[]"][value="gramatura"]');
    await page.check('input[name="obrigatorios[]"][value="densidade"]');
    await page.check('input[name="pede[]"][value="espessura_mm"]');
    await salvarGrupo(grupos.espuma);
    const selos = await page.locator(`.grupos-item[data-grupo="${grupos.espuma}"] .grupo-selo`).allInnerTexts();
    if (selos.join(",") !== "Base,Não estampa") throw new Error(`Espuma's selos: ${selos}`);
    const pede = await page.$$eval('input[name="pede[]"]:checked', (is) => is.map((i) => i.value));
    if (pede.join(",") !== "densidade,espessura_mm") throw new Error(`Espuma asks: ${pede}`);

    // Ressalvas need their text: the page says so and keeps the choice.
    await abrirGrupo(grupos.tnt);
    await page.check("#grupo_material_estampavel_ressalvas");
    await page.locator('.grupo-form input[type="submit"]').click();
    await waitForText(page, "Ressalva diz qual é a ressalva");
    await page.fill("#grupo_material_ressalva", "a cor fica mais clara");
    await salvarGrupo(grupos.tnt);

    await abrirGrupo(grupos.telinha);
    await page.check("#grupo_material_estampavel_nao");
    await salvarGrupo(grupos.telinha);
  });

  await test("The stock entry shows the group's fields and refuses a missing required one", async () => {
    await page.goto(`${BASE_URL}/movimentos/new`);
    await page.click('input[name="movimento_estoque[da_empresa]"][value="true"]');
    await page.fill("[data-group-select-target=input]", grupos.espuma);
    await page.locator(`.combobox-option[data-name="${grupos.espuma}"]`).click();
    const densidade = page.locator('[data-atributo="densidade"]');
    await densidade.waitFor({ state: "visible" });
    // Espuma isn't weighed: its gramatura is neither shown nor sent.
    if (await page.locator('[data-atributo="gramatura"]').isVisible()) throw new Error("Espuma shows a gramatura it doesn't ask");
    if (!(await densidade.locator(".atributo-obrigatorio").isVisible())) throw new Error("Densidade isn't marked required");
    await page.click(`.color-swatch[title="Branco"]`);
    await page.fill("#movimento_estoque_espessura_mm", "3");
    await page.fill("#movimento_estoque_quantidade", "12");
    await page.click('input[type="submit"][value="Register Movement"]');
    await waitForText(page, `Densidade é obrigatório no grupo ${grupos.espuma}`);
    // Re-rendered with the group's fields, from the server.
    await page.fill("#movimento_estoque_densidade", "TC4");
    await page.click('input[type="submit"][value="Register Movement"]');
    await waitForText(page, `of ${grupos.espuma} TC4 3 mm-Branco-1.40 m`);
  });

  await test("A tecido pedido offers only what prints and warns of a ressalva", async () => {
    for (const grupo of ["tnt", "telinha"]) await entrada(grupo);
    ids.tnt_material = (await material(grupos.tnt)).id;
    await page.goto(`${BASE_URL}/arquivos`);
    await page.selectOption('[data-upload-target="tipo"]', "corrida");
    const destino = path.join(pasta, `${nomes.corrida}.tif`);
    execFileSync("convert", ["-size", "60x60", "xc:#3a6", destino]);
    await uploadFileAndWait(page, destino);
    const cartao = page.locator(".stamp-card").filter({ hasText: nomes.corrida });
    const arquivo = (await cartao.getAttribute("id")).replace(/^arquivo_/, "");
    await postar(`/arquivos/${arquivo}/update_client`, { _method: "patch", client_uuid: ids.cliente });
    await page.goto(`${BASE_URL}/arquivos`);

    await cartao.locator(".btn-add-to-order").click();
    const modal = page.locator("dialog.add-to-order-dialog[open]");
    await modal.locator(".add-to-order-material .combobox-input").fill(String(U));
    await modal.locator(".add-to-order-material .combobox-option[data-id]").first().waitFor();
    const oferecidos = await modal.locator(".add-to-order-material .combobox-option[data-id]").evaluateAll((os) => os.map((o) => o.dataset.name));
    // Telinha and Espuma don't print (their groups say "não"): never offered.
    if (oferecidos.length !== 1 || !oferecidos[0].startsWith(grupos.tnt)) throw new Error(`The modal offers ${oferecidos}`);
    await modal.locator(".add-to-order-material .combobox-option[data-id]").first().click();
    await modal.locator(".add-to-order-metros").fill("4");
    const [resposta] = await Promise.all([
      page.waitForResponse((r) => r.url().includes("/pedidos/adicionar_item")),
      modal.locator('button:has-text("Adicionar")').click(),
    ]);
    const dados = await resposta.json();
    if (!dados.ok) throw new Error(`Adding the corrida failed: ${dados.error}`);

    await page.goto(`${BASE_URL}/pedidos/${dados.pedido_uuid}`);
    const item = page.locator(".pedido-item-tecido").first();
    await item.locator(".pedido-tecido-ressalva").waitFor();
    const aviso = (await item.locator(".pedido-tecido-ressalva").innerText()).trim();
    if (aviso !== `${grupos.tnt} estampa com ressalvas: a cor fica mais clara`) throw new Error(`The ressalva says "${aviso}"`);
    const opcoes = await item.locator(".pedido-tecido-material option").allInnerTexts();
    if (opcoes.some((o) => o.startsWith(grupos.telinha) || o.startsWith(grupos.espuma))) throw new Error(`The item offers what doesn't print: ${opcoes}`);
    if (!opcoes.some((o) => o.startsWith(grupos.tnt))) throw new Error(`The item doesn't offer the TNT: ${opcoes}`);
    fs.rmSync(pasta, { recursive: true, force: true });
  });
});
