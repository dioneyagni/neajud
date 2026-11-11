// Dublagem 5b1c1 (decided 11/11/2026; plano 2.9, 5b Q5a–Q8a): an item
// whose construção dubs after the Calandra is dubbed in the pedido. Oxford
// over Oxford with filme (DUB-A, before the Calandra: the estampa goes on
// it), then DUB-A over Espuma with cola (DUB-B, after). Confirmed, the
// pedido has Dublagem and Dublagem final, a line per item × letra; the
// Calandra waits for the paper and DUB-A, DUB-B for the Calandra.
const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");
const { BASE_URL, runSpec } = require("./support/runner");
const { uploadFileAndWait } = require("./support/upload");
const { waitForText } = require("./support/wait");
const { postar, buscarJson } = require("./support/corrida");
const { prepararDublagem, grupo, material } = require("./support/dublagem");

runSpec("Dublagem no pedido E2E Tests", async ({ page, test }) => {
  const U = `${Date.now()}`.slice(-6);
  const nomes = { cliente: `No pedido ${U}`, corrida: `nopedido${U}`, espuma: `Espuma-Branco-1.40 m-${U}e` };
  const ids = {};

  async function salvarItem(acao) {
    await page.evaluate(() => { document.body.dataset.antigo = "1"; });
    await acao();
    await page.locator("body:not([data-antigo])").waitFor({ state: "attached" });
  }

  const linha = (letra) => page.locator(`tr[data-letra="${letra}"]`);
  const etapa = (chave) => page.goto(`${BASE_URL}/pedidos/${ids.pedido}/tecido/producao/${chave}`);

  async function darBaixa(local, medida) {
    await local.locator(".baixa-abrir").click();
    await local.locator(".baixa-medida").fill(medida);
    await Promise.all([page.waitForResponse((r) => new URL(r.url()).pathname === `/pedidos/${ids.pedido}/baixas` && r.status() === 200),
      local.locator(".baixa-salvar").click()]);
    await page.getByText(/^Baixa de .* registrada/).waitFor();
  }

  await test("Setup: a construção with a dublagem after the Calandra, a client and his corrida", async () => {
    const dublagem = await prepararDublagem(page, `${U}n`);
    const cor = (await buscarJson(page, "/materiais/cores")).find((c) => c.nome === "Branco").id;
    const espuma = await material(page, cor, await grupo(page, "Espuma"), nomes.espuma, { "movimento_estoque[gramatura]": `${U}e` }, "tecido", `${U}e`);
    const salva = await page.evaluate(async (campos) => {
      const token = document.querySelector('meta[name="csrf-token"]')?.content || "";
      return (await fetch("/construcoes", { method: "POST", body: new URLSearchParams({ authenticity_token: token, ...campos }) })).url;
    }, {
      "construcao[situacao]": "", "construcao[client_uuid]": "", "construcao[preco_final]": "50",
      "construcao[dublagens][0][cima][escolha]": dublagem.ids.oxford, "construcao[dublagens][0][cima][lado]": "trama",
      "construcao[dublagens][0][baixo][escolha]": dublagem.ids.oxford, "construcao[dublagens][0][ligante_uuid]": dublagem.ids.filme,
      "construcao[dublagens][1][cima][escolha]": "dublagem:0", "construcao[dublagens][1][baixo][escolha]": espuma,
    });
    ids.construcao = salva.match(/construcoes\/([0-9a-f-]{36})\/edit/)?.[1];
    if (!ids.construcao) throw new Error(`The construção wasn't saved: ${salva}`);
    ids.oxford = dublagem.ids.oxford;
    await postar(page, "/parametros", { _method: "patch", "empresa[preco_impressao_metro_tecido]": "15" });

    await postar(page, "/clients", { "client[name]": nomes.cliente, "client[responsible]": "T" });
    ids.cliente = (await buscarJson(page, `/clients/search?q=${encodeURIComponent(nomes.cliente)}`)).find((c) => c.name === nomes.cliente).id;
    const pasta = fs.mkdtempSync(path.join(os.tmpdir(), "nopedido-"));
    const arquivo = path.join(pasta, `${nomes.corrida}.tif`);
    execFileSync("convert", ["-size", "60x60", "xc:#36a", arquivo]);
    await page.goto(`${BASE_URL}/arquivos`);
    await page.selectOption('[data-upload-target="tipo"]', "corrida");
    await uploadFileAndWait(page, arquivo);
    fs.rmSync(pasta, { recursive: true, force: true });
    ids.corrida = (await page.locator(".stamp-card").filter({ hasText: nomes.corrida }).getAttribute("id")).replace(/^arquivo_/, "");
    await postar(page, `/arquivos/${ids.corrida}/update_client`, { _method: "patch", client_uuid: ids.cliente });
  });

  await test("The item says its letras are made in the pedido; confirmed, it has the Dublagem stages", async () => {
    const resposta = await page.evaluate(async ({ corrida, oxford }) => {
      const token = document.querySelector('meta[name="csrf-token"]')?.content || "";
      const campos = { authenticity_token: token, arquivo_uuid: corrida, materia_prima_uuid: oxford, metros: "12" };
      return (await fetch("/pedidos/adicionar_item", { method: "POST", headers: { Accept: "application/json" }, body: new URLSearchParams(campos) })).json();
    }, { corrida: ids.corrida, oxford: ids.oxford });
    if (!resposta.ok) throw new Error(`adicionar_item failed: ${resposta.error}`);
    ids.pedido = resposta.pedido_uuid;
    await page.goto(`${BASE_URL}/pedidos/${ids.pedido}/resumo`);
    await salvarItem(() => page.selectOption(".pedido-tecido-construcao", ids.construcao));
    const producao = (await page.locator("[data-dublagem-producao]").innerText()).trim();
    if (producao !== "dublado no pedido: DUB-A (Dublagem) · DUB-B (Dublagem final)") throw new Error(`The item says ${producao}`);
    if (await page.locator(".pedido-confirmar").isDisabled()) throw new Error(`Can't confirm: ${(await page.locator(".pedido-painel, body").first().innerText()).replace(/\s+/g, " ").slice(0, 600)}`);
    await page.locator(".pedido-confirmar").click();
    await waitForText(page, "Pedido confirmed.");

    await etapa("impressao");
    const abas = await page.locator(".etapas-nav-link").evaluateAll((ls) => ls.map((l) => l.dataset.etapa));
    if (abas.join("|") !== "impressao|dublagem|calandra|dublagem_final") throw new Error(`The stages are ${abas}`);
  });

  await test("Each line waits for what its letra needs, and takes its baixa once that is done", async () => {
    await etapa("dublagem_final");
    await linha("DUB-B").locator(".baixa-aguardando", { hasText: "aguardando Calandra" }).waitFor();
    await etapa("calandra");
    await page.locator(".producao-tecido-linha .baixa-aguardando", { hasText: "aguardando Impressão" }).waitFor();

    await etapa("dublagem");
    if (!(await linha("DUB-A").innerText()).includes("Oxford Branco / Oxford Branco")) throw new Error("DUB-A's line doesn't say what it joins");
    await darBaixa(linha("DUB-A"), "12");
    await etapa("impressao");
    await darBaixa(page.locator(".producao-tecido-linha"), "12");
    await etapa("calandra");
    await darBaixa(page.locator(".producao-tecido-linha"), "12");
    await etapa("dublagem_final");
    await darBaixa(linha("DUB-B"), "12");
    await linha("DUB-B").locator(".baixa-feita", { hasText: "✓ 12,00 m" }).waitFor();
  });

  await test("The Dublagem's page fits a phone, never scrolling sideways", async () => {
    await etapa("dublagem");
    await page.setViewportSize({ width: 390, height: 800 });
    const larguras = await page.evaluate(() => [document.documentElement.scrollWidth, window.innerWidth]);
    await page.setViewportSize({ width: 1280, height: 800 });
    if (larguras[0] > larguras[1]) throw new Error(`The page scrolls sideways: ${larguras.join(" > ")}`);
  });
});
