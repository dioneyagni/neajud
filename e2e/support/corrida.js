// A client's fabric in stock and his corrida, and confirmed pedidos of it —
// the tecido pedidos the Painel's queue specs move and turn (painel-
// programacao, painel-virada). Each spec gets its own names.
//
// Usage: const corrida = await prepararCorrida(page, "prog");
//        const uuid = await pedidoDaCorrida(page, corrida);
//        limparCorrida(corrida);
const fs = require("fs");
const os = require("os");
const path = require("path");
const { BASE_URL } = require("./runner");
const { uploadFileAndWait } = require("./upload");
const { waitForText } = require("./wait");

async function postar(page, url, campos) {
  return page.evaluate(async ({ url, campos }) => {
    const token = document.querySelector('meta[name="csrf-token"]')?.content || "";
    return (await fetch(url, { method: "POST", body: new URLSearchParams({ authenticity_token: token, ...campos }) })).ok;
  }, { url, campos });
}

async function buscarJson(page, url) {
  return page.evaluate(async (url) => (await fetch(url, { headers: { Accept: "application/json" } })).json(), url);
}

async function prepararCorrida(page, rotulo) {
  const U = Date.now();
  const nomes = { corrida: `corrida${rotulo}${U}`, cliente: `Malharia ${rotulo} ${U}`, grupo: `Helanca${rotulo}${U}` };
  // Outside the repo: an "e2e-" prefix would be read as part of the name.
  const pasta = fs.mkdtempSync(path.join(os.tmpdir(), `${rotulo}-`));
  const original = path.join(pasta, `${nomes.corrida}.tif`);
  const ids = {};

  await page.goto(`${BASE_URL}/parametros/edit`);
  await page.fill("#empresa_preco_impressao_metro_tecido", "15");
  await page.click('input[type="submit"][value="Save"]');
  await waitForText(page, "Production parameters saved.");
  if (!(await postar(page, "/clients", { "client[name]": nomes.cliente, "client[responsible]": "T" }))) throw new Error("Couldn't create the client");
  ids.cliente = (await buscarJson(page, `/clients/search?q=${encodeURIComponent(nomes.cliente)}`)).find((c) => c.name === nomes.cliente).id;
  await postar(page, "/materiais/create_grupo", { "grupo_material[nome]": nomes.grupo });
  const grupo = (await buscarJson(page, `/materiais/grupos?q=${nomes.grupo}`)).find((g) => g.nome === nomes.grupo).id;
  const cor = (await buscarJson(page, "/materiais/cores")).find((c) => c.nome === "Branco")?.id || (await postar(page, "/materiais/create_cor", { "cor_material[nome]": "Branco" }), (await buscarJson(page, "/materiais/cores")).find((c) => c.nome === "Branco").id);
  await postar(page, "/materiais", {
    "movimento_estoque[client_uuid]": ids.cliente, "movimento_estoque[tipo]": "entrada", "movimento_estoque[grupo_material_uuid]": grupo,
    "movimento_estoque[cor_material_uuid]": cor, "movimento_estoque[largura]": "1.50", "movimento_estoque[gramatura]": "120g", "movimento_estoque[quantidade]": "40",
  });
  ids.tecido = (await buscarJson(page, `/materiais/search?tipo=tecido&q=${nomes.grupo}`))[0]?.id;

  fs.copyFileSync(path.join(__dirname, "..", "..", "spec", "fixtures", "files", "01.tif"), original);
  await page.goto(`${BASE_URL}/arquivos`);
  await page.selectOption('[data-upload-target="tipo"]', "corrida");
  await uploadFileAndWait(page, original);
  await page.selectOption('[data-upload-target="tipo"]', "calcado");
  ids.corrida = (await page.locator(".stamp-card").filter({ hasText: nomes.corrida }).getAttribute("id")).replace(/^arquivo_/, "");
  if (!(await postar(page, `/arquivos/${ids.corrida}/update_client`, { _method: "patch", client_uuid: ids.cliente }))) throw new Error("Couldn't give the corrida its client");
  return { nomes, ids, pasta };
}

// A pedido of the corrida, its fabric chosen, confirmed.
async function pedidoDaCorrida(page, { nomes, ids }) {
  await page.goto(`${BASE_URL}/arquivos`);
  await page.locator(".stamp-card").filter({ hasText: nomes.corrida }).locator(".btn-add-to-order").click();
  const modal = page.locator("dialog.add-to-order-dialog[open]");
  await modal.locator(".add-to-order-metros").fill("12,5");
  const [resposta] = await Promise.all([
    page.waitForResponse((r) => r.url().includes("/pedidos/adicionar_item")),
    modal.locator('button:has-text("Adicionar")').click(),
  ]);
  const uuid = (await resposta.json()).pedido_uuid;
  await page.goto(`${BASE_URL}/pedidos/${uuid}/resumo`);
  await page.locator("select.pedido-tecido-material").first().selectOption(ids.tecido);
  await page.locator(".pedido-pendencia--sem_material").waitFor({ state: "detached", timeout: 10000 });
  await page.locator(".pedido-confirmar").click();
  await waitForText(page, "Pedido confirmed.");
  return uuid;
}

function limparCorrida({ pasta }) {
  fs.rmSync(pasta, { recursive: true, force: true });
}

module.exports = { prepararCorrida, pedidoDaCorrida, limparCorrida, postar, buscarJson };
