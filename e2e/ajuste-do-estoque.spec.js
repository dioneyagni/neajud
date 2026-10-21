const path = require("path");
const fs = require("fs");
const os = require("os");
const { execFileSync } = require("child_process");
const { uploadFileAndWait } = require("./support/upload");
const { waitForText } = require("./support/wait");
const { BASE_URL, runSpec } = require("./support/runner");

// Etapa 2.3e (decided 20/10/2026): a metragem baixa adjusts the stock by the
// real minus the expected — an out of what passed it, an entry of what was
// left — one measure per material when the lines take several. Shown in the
// stage's history, the ledger and the pedido's panel; undoing the baixa stops
// the adjustment counting.
runSpec("Ajuste do estoque", async ({ page, test }) => {
  const U = `${Date.now()}`.slice(-6);
  const nomes = { cliente: `Ajuste ${U}`, oxford: `OxAjuste${U}`, helanca: `HeAjuste${U}`, papel: `PapAjuste${U}` };
  const ids = {};
  const pasta = fs.mkdtempSync(path.join(os.tmpdir(), "neajud-ajuste-"));

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

  // An entry of a material (the client's when given, else the empresa's); its uuid.
  async function entrada(grupo, metros, cliente) {
    await postar("/materiais/create_grupo", { "grupo_material[nome]": grupo });
    const grupoUuid = (await buscarJson(`/materiais/grupos?q=${grupo}`)).find((g) => g.nome === grupo).id;
    const cor = (await buscarJson("/materiais/cores"))[0].id;
    const dono = cliente ? { "movimento_estoque[client_uuid]": cliente } : { "movimento_estoque[da_empresa]": "1" };
    await postar("/materiais", { ...dono, "movimento_estoque[tipo]": "entrada", "movimento_estoque[grupo_material_uuid]": grupoUuid, "movimento_estoque[cor_material_uuid]": cor,
      "movimento_estoque[largura]": "1.60", "movimento_estoque[gramatura]": "100g", "movimento_estoque[quantidade]": metros });
    return (await buscarJson(`/materiais/search?q=${grupo}`))[0].id;
  }

  async function corrida(nome) {
    const arquivo = path.join(pasta, `${nome}.tif`);
    execFileSync("convert", ["-size", "60x60", "xc:#36a", arquivo]);
    await page.goto(`${BASE_URL}/arquivos`);
    await page.selectOption('[data-upload-target="tipo"]', "corrida");
    await uploadFileAndWait(page, arquivo);
    const uuid = (await page.locator(".stamp-card").filter({ hasText: nome }).getAttribute("id")).replace(/^arquivo_/, "");
    await postar(`/arquivos/${uuid}/update_client`, { _method: "patch", client_uuid: ids.cliente });
    return uuid;
  }

  async function adicionar(arquivo, tecido) {
    const resposta = await page.evaluate(async ({ arquivo, tecido }) => {
      const token = document.querySelector('meta[name="csrf-token"]')?.content || "";
      const campos = { authenticity_token: token, arquivo_uuid: arquivo, materia_prima_uuid: tecido, metros: "12" };
      return (await fetch("/pedidos/adicionar_item", { method: "POST", headers: { Accept: "application/json" }, body: new URLSearchParams(campos) })).json();
    }, { arquivo, tecido });
    if (!resposta.ok) throw new Error(`adicionar_item failed: ${resposta.error}`);
    return resposta.pedido_uuid;
  }

  async function etapa(nome) {
    await page.goto(`${BASE_URL}/pedidos/${ids.pedido}/tecido/producao/${nome}`);
  }

  async function salvarBaixa(acao) {
    await Promise.all([page.waitForResponse((r) => new URL(r.url()).pathname === `/pedidos/${ids.pedido}/baixas` && r.status() === 200), acao()]);
    await page.getByText(/^Baixa de .* registrada/).waitFor();
  }

  async function historico() {
    await page.locator(".historico-baixas summary").click();
    return (await page.locator(".historico-baixa:not(.historico-baixa--desfeita) [data-estoque]").last().innerText()).trim();
  }

  async function consumo(material) {
    await page.goto(`${BASE_URL}/pedidos/${ids.pedido}/resumo`);
    return (await page.locator(`[data-resumo="consumo"] dd[data-consumo="${material}"]`).innerText()).replace(/\s+/g, " ").trim();
  }

  try {
    await test("Setup: a client with two fabrics of his, a paper of the empresa and two corridas", async () => {
      await page.goto(`${BASE_URL}/arquivos`);
      await postar("/clients", { "client[name]": nomes.cliente, "client[responsible]": "T" });
      ids.cliente = (await buscarJson(`/clients/search?q=${encodeURIComponent(nomes.cliente)}`)).find((c) => c.name === nomes.cliente).id;
      ids.oxford = await entrada(nomes.oxford, "30", ids.cliente);
      ids.helanca = await entrada(nomes.helanca, "30", ids.cliente);
      ids.papel = await entrada(nomes.papel, "100");
      await postar(`/materiais/${ids.papel}`, { _method: "patch", "materia_prima[tipo]": "papel" });
      for (const tecido of [ids.oxford, ids.helanca]) await postar(`/materiais/${tecido}`, { _method: "patch", "materia_prima[preco_metro]": "20" });
      // Etapa 2.7b: no price, no confirming.
      await postar("/parametros", { _method: "patch", "empresa[preco_impressao_metro_tecido]": "15" });
      ids.corridaOx = await corrida(`ajox${U}`);
      ids.corridaHe = await corrida(`ajhe${U}`);
    });

    await test("A confirmed tecido pedido: 12 m on each fabric (each item past the 10 m minimum precos-tecido leaves set), on the empresa's paper", async () => {
      await page.goto(`${BASE_URL}/arquivos`);
      ids.pedido = await adicionar(ids.corridaOx, ids.oxford);
      if ((await adicionar(ids.corridaHe, ids.helanca)) !== ids.pedido) throw new Error("Both items should go into the same draft");
      await page.goto(`${BASE_URL}/pedidos/${ids.pedido}/resumo`);
      await page.selectOption("#pedido-material-impressao", ids.papel);
      await page.locator('[data-resumo="material-impressao"]', { hasText: nomes.papel }).waitFor({ timeout: 10000 });
      if (await page.locator(".pedido-confirmar").isDisabled()) throw new Error(`Can't confirm: ${(await page.locator(".pedido-pendencias").innerText()).replace(/\s+/g, " ")}`);
      await page.locator(".pedido-confirmar").click();
      await waitForText(page, "Pedido confirmed.");
      if ((await consumo(ids.papel)) !== "saída 24 m") throw new Error(`The paper reads ${await consumo(ids.papel)} before any baixa`);
    });

    await test("The Impressão used 1 m past the expected: the paper's out grows by it", async () => {
      await etapa("impressao");
      const baixa = page.locator(".etapa-andamento .baixa");
      await baixa.locator(".baixa-abrir").click();
      await baixa.locator(".baixa-medida").fill("25");
      await salvarBaixa(() => baixa.locator(".baixa-salvar").click());
      const linha = await historico();
      if (!linha.includes(`+1 m ${nomes.papel}`) || !linha.includes("(Empresa)")) throw new Error(`The history reads ${linha}`);
      const papel = await consumo(ids.papel);
      if (papel !== "saída 24 m · ajustes +1 m · real até agora 25 m") throw new Error(`The panel reads ${papel}`);
    });

    await test("The Calandra of the pedido asks each fabric's measure, and adjusts each by its own", async () => {
      await etapa("calandra");
      const baixa = page.locator(".etapa-andamento .baixa");
      await baixa.locator(".baixa-abrir").click();
      const campos = baixa.locator(".baixa-material");
      if ((await campos.count()) !== 2) throw new Error(`Expected one field per fabric, got ${await campos.count()}`);
      await baixa.locator(`.baixa-material[data-material="${ids.oxford}"] .baixa-medida`).fill("12,5");
      await baixa.locator(".baixa-salvar").click();
      await baixa.locator(".baixa-mensagem", { hasText: "Missing the measure of" }).waitFor();
      await baixa.locator(`.baixa-material[data-material="${ids.helanca}"] .baixa-medida`).fill("11,5");
      await salvarBaixa(() => baixa.locator(".baixa-salvar").click());
      const linha = await historico();
      if (!linha.includes(`+0,5 m ${nomes.oxford}`) || !linha.includes(`−0,5 m ${nomes.helanca}`)) throw new Error(`The history reads ${linha}`);
      if ((await consumo(ids.helanca)) !== "saída 12 m · ajustes −0,5 m · real até agora 11,5 m") throw new Error(`The panel reads ${await consumo(ids.helanca)}`);
      await page.goto(`${BASE_URL}/movimentos`);
      const ajustes = await page.locator(`[data-pedido="${ids.pedido}"] .movimento-etapa`).allInnerTexts();
      if (ajustes.filter((t) => t.includes("Calandra")).length !== 2) throw new Error(`The ledger's adjustments: ${ajustes.join(" | ")}`);
    });

    await test("Undoing the Calandra stops its adjustments counting: the ledger says so, the panel goes back", async () => {
      await etapa("calandra");
      await Promise.all([page.waitForURL(`**/pedidos/${ids.pedido}/tecido/producao/calandra`), page.locator(".baixa-desfazer").first().click()]);
      await page.getByText("Baixa de Calandra desfeita").waitFor();
      await page.goto(`${BASE_URL}/movimentos`);
      const naoContam = await page.locator(`[data-pedido="${ids.pedido}"] .movimento-nao-conta`).allInnerTexts();
      if (naoContam.length !== 2 || naoContam.some((t) => t !== "baixa desfeita: não conta")) throw new Error(`The ledger reads ${naoContam.join(" | ")}`);
      if ((await consumo(ids.oxford)) !== "saída 12 m") throw new Error(`The panel reads ${await consumo(ids.oxford)}`);
    });
  } finally {
    fs.rmSync(pasta, { recursive: true, force: true });
  }
});
