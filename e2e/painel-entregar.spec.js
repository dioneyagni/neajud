const path = require("path");
const fs = require("fs");
const os = require("os");
const { execFileSync } = require("child_process");
const { uploadFileAndWait } = require("./support/upload");
const { waitForText } = require("./support/wait");
const { BASE_URL, runSpec } = require("./support/runner");

// Entregar pelo Painel (decided 08/11/2026): the resumo's "Marcar como
// entregue" in the faixa, and a shortcut in the "pronto p/ entregar" cell
// that asks in the cell first (Q1c, Q2a: cells sit side by side and a
// delivery is not undone). Delivered, the Painel refreshes itself — what
// was open stays open — and a short warning takes the row's place (Q3a).
// Two tecido pedidos of one client: the first printed and calandered, its
// fabric covered; the second only printed, 4 m of fabric short.
runSpec("Painel: entregar", async ({ page, test }) => {
  const U = `${Date.now()}`.slice(-6);
  const nomes = { cliente: `Entrega Painel ${U}`, tecido: `TecEntPai${U}`, papel: `PapEntPai${U}`, corrida: `entpainel${U}` };
  const ids = {};
  const pasta = fs.mkdtempSync(path.join(os.tmpdir(), "neajud-entregar-"));
  const entregas = [];
  page.on("request", (r) => { if (r.method() === "POST" && r.url().endsWith("/entregar")) entregas.push(r.url()) });

  // json: the endpoint answers JSON (adicionar_item, baixas); the forms' HTML ones would answer 406.
  async function postar(url, campos, { json = false } = {}) {
    return page.evaluate(async ({ url, campos, json }) => {
      const token = document.querySelector('meta[name="csrf-token"]')?.content || "";
      const headers = json ? { Accept: "application/json" } : {};
      const resposta = await fetch(url, { method: "POST", headers, body: new URLSearchParams({ authenticity_token: token, ...campos }) });
      return json ? resposta.json() : { ok: resposta.ok };
    }, { url, campos, json });
  }

  async function buscarJson(url) {
    return page.evaluate(async (url) => (await fetch(url, { headers: { Accept: "application/json" } })).json(), url);
  }

  async function entrada(grupo, largura, metros, cliente) {
    await postar("/materiais/create_grupo", { "grupo_material[nome]": grupo });
    const grupoUuid = (await buscarJson(`/materiais/grupos?q=${grupo}`)).find((g) => g.nome === grupo).id;
    const cor = (await buscarJson("/materiais/cores"))[0].id;
    const dono = cliente ? { "movimento_estoque[client_uuid]": cliente } : { "movimento_estoque[da_empresa]": "1" };
    await postar("/materiais", { ...dono, "movimento_estoque[tipo]": "entrada", "movimento_estoque[grupo_material_uuid]": grupoUuid, "movimento_estoque[cor_material_uuid]": cor,
      "movimento_estoque[largura]": largura, "movimento_estoque[gramatura]": "100g", "movimento_estoque[quantidade]": metros });
    return (await buscarJson(`/materiais/search?q=${grupo}`))[0].id;
  }

  // A confirmed tecido pedido of 12 m of the corrida on the client's fabric.
  async function pedidoConfirmado() {
    const resposta = await postar("/pedidos/adicionar_item", { arquivo_uuid: ids.corrida, materia_prima_uuid: ids.tecido, metros: "12" }, { json: true });
    if (!resposta.ok) throw new Error(`adicionar_item failed: ${resposta.error}`);
    await page.goto(`${BASE_URL}/pedidos/${resposta.pedido_uuid}/resumo`);
    await page.selectOption("#pedido-material-impressao", ids.papel);
    await page.locator('[data-resumo="material-impressao"]', { hasText: nomes.papel }).waitFor({ timeout: 10000 });
    await page.locator(".pedido-confirmar").click();
    await waitForText(page, "Pedido confirmed.");
    return resposta.pedido_uuid;
  }

  async function baixa(pedido, etapa) {
    const resposta = await postar(`/pedidos/${pedido}/baixas`, { etapa, nivel: "pedido", medida: "12", confirmar: "1" }, { json: true });
    if (!resposta.ok) throw new Error(`The ${etapa} baixa answered ${JSON.stringify(resposta)}`);
  }

  function linha(uuid) {
    return page.locator(`#painel_${uuid}`);
  }

  async function abrir(uuid) {
    await linha(uuid).locator(".painel-ped-btn").first().click();
    await linha(uuid).locator(":scope > .painel-faixa").waitFor({ state: "visible" });
  }

  try {
    await test("Setup: two tecido pedidos — one printed and calandered, one printed with 4 m of fabric short", async () => {
      await page.goto(`${BASE_URL}/arquivos`);
      await postar("/clients", { "client[name]": nomes.cliente, "client[responsible]": "T" });
      ids.cliente = (await buscarJson(`/clients/search?q=${encodeURIComponent(nomes.cliente)}`)).find((c) => c.name === nomes.cliente).id;
      ids.tecido = await entrada(nomes.tecido, "1.40", "20", ids.cliente);
      ids.papel = await entrada(nomes.papel, "1.60", "100");
      await postar(`/materiais/${ids.papel}`, { _method: "patch", "materia_prima[tipo]": "papel" });
      await postar(`/materiais/${ids.tecido}`, { _method: "patch", "materia_prima[preco_metro]": "20" });
      await postar("/parametros", { _method: "patch", "empresa[preco_impressao_metro_tecido]": "15" });

      const arquivo = path.join(pasta, `${nomes.corrida}.tif`);
      execFileSync("convert", ["-size", "60x60", "xc:#36a", arquivo]);
      await page.goto(`${BASE_URL}/arquivos`);
      await page.selectOption('[data-upload-target="tipo"]', "corrida");
      await uploadFileAndWait(page, arquivo);
      ids.corrida = (await page.locator(".stamp-card").filter({ hasText: nomes.corrida }).getAttribute("id")).replace(/^arquivo_/, "");
      await postar(`/arquivos/${ids.corrida}/update_client`, { _method: "patch", client_uuid: ids.cliente });

      ids.pronto = await pedidoConfirmado();
      ids.curto = await pedidoConfirmado();
      await baixa(ids.pronto, "impressao");
      await baixa(ids.pronto, "calandra");
      await baixa(ids.curto, "impressao");
    });

    await test("The ready pedido's Entrega cell asks in the cell; Não leaves it as it was, with nothing sent", async () => {
      await page.goto(`${BASE_URL}/painel`);
      const celula = linha(ids.pronto).locator(":scope > .painel-linha [data-coluna=entrega]");
      if ((await celula.getAttribute("data-estado")) !== "pode_comecar") throw new Error(`The cell is ${await celula.getAttribute("data-estado")}`);
      // Still printing its Calandra: no shortcut, only the faixa's button.
      if (await linha(ids.curto).locator(".entrega-atalho").count()) throw new Error("A pedido still in production got the shortcut");
      await celula.locator(".entrega-atalho").click();
      const pergunta = celula.locator(".entrega-pergunta");
      await pergunta.waitFor({ state: "visible" });
      if ((await pergunta.innerText()).replace(/\s+/g, " ").trim() !== `Entregar #${ids.pronto.slice(0, 8)}? Sim Não`) throw new Error(`The cell asks ${await pergunta.innerText()}`);
      await pergunta.locator(".entrega-nao").click();
      await celula.locator(".entrega-atalho").waitFor({ state: "visible" });
      if (await pergunta.isVisible()) throw new Error("Não left the question open");
      if (entregas.length) throw new Error(`Não delivered: ${entregas.join(", ")}`);
    });

    await test("Sim delivers it: the page refreshes by itself, the other pedido stays open, a warning takes the row's place", async () => {
      await abrir(ids.curto);
      const celula = linha(ids.pronto).locator(":scope > .painel-linha [data-coluna=entrega]");
      await celula.locator(".entrega-atalho").click();
      await celula.locator(".entrega-sim").click();
      const aviso = page.locator(`#entregue_painel_${ids.pronto}`);
      await aviso.waitFor({ state: "visible", timeout: 10000 });
      await linha(ids.pronto).waitFor({ state: "detached" });
      if ((await aviso.innerText()).trim() !== `#${ids.pronto.slice(0, 8)} entregue · ver em Entregues`) throw new Error(`The warning reads ${await aviso.innerText()}`);
      if (!(await aviso.locator("a").getAttribute("href")).includes("entregues=1")) throw new Error("The warning should link to the delivered ones");
      if (!(await linha(ids.curto).evaluate((el) => el.classList.contains("painel-pedido--aberto")))) throw new Error("The other pedido's faixa closed");
      // Q3a: it lasts a few seconds.
      await aviso.waitFor({ state: "detached", timeout: 10000 });
      await page.goto(`${BASE_URL}/pedidos/${ids.pronto}/resumo`);
      await page.locator(".pedido-entregue", { hasText: "Entregue em" }).waitFor();
    });

    await test("From the faixa: the open stage is named, Entregar assim mesmo asks for the fabric short; Cancelar delivers nothing", async () => {
      await page.goto(`${BASE_URL}/painel`);
      await abrir(ids.curto);
      const entrega = linha(ids.curto).locator("[data-faixa-entrega] .entrega");
      await entrega.locator(".entrega-botao").click();
      await entrega.locator(".baixa-aviso", { hasText: "Ainda faltam: Calandra 1 linha. Entregar assim mesmo?" }).waitFor();
      await entrega.locator(".entrega-confirmar").click();
      const dialogo = entrega.locator("dialog.baixa-falta");
      await dialogo.waitFor({ state: "visible" });
      const caixa = await dialogo.boundingBox();
      const tela = page.viewportSize();
      if (Math.abs(caixa.x + caixa.width / 2 - tela.width / 2) > 2 || Math.abs(caixa.y + caixa.height / 2 - tela.height / 2) > 2) throw new Error(`Dialog not centered: ${JSON.stringify(caixa)}`);
      if ((await dialogo.locator("input[data-chave]").inputValue()) !== "4") throw new Error(`The entry starts at ${await dialogo.locator("input[data-chave]").inputValue()}, expected the 4 m short`);
      await dialogo.getByText("Cancelar").click();
      await dialogo.waitFor({ state: "hidden" });
      await page.reload();
      await linha(ids.curto).waitFor();
    });

    await test("With Mostrar entregues on, launching the entry delivers it: the row moves to Entregues, no warning", async () => {
      await page.goto(`${BASE_URL}/painel?entregues=1`);
      await abrir(ids.curto);
      const entrega = linha(ids.curto).locator("[data-faixa-entrega] .entrega");
      await entrega.locator(".entrega-botao").click();
      await entrega.locator(".entrega-confirmar").click();
      const dialogo = entrega.locator("dialog.baixa-falta");
      await dialogo.waitFor({ state: "visible" });
      await dialogo.locator(".baixa-falta-lancar").click();
      await page.locator(`.painel-bloco-pedidos[data-bloco=entregues] > #painel_${ids.curto}`).waitFor({ timeout: 10000 });
      if (await page.locator(".painel-entregue-aviso").count()) throw new Error("Still listed, it needs no warning");
      if (await page.locator("dialog.baixa-falta[open]").count()) throw new Error("The dialog stayed open");
      if (await linha(ids.curto).locator("[data-controller=entrega]").count()) throw new Error("A delivered pedido still offers the delivery");
    });
  } finally {
    fs.rmSync(pasta, { recursive: true, force: true });
  }
});
