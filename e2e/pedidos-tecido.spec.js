const path = require("path");
const fs = require("fs");
const os = require("os");
const { execFileSync } = require("child_process");
const { uploadFileAndWait } = require("./support/upload");
const { waitForText } = require("./support/wait");
const { BASE_URL, runSpec } = require("./support/runner");

// Decided 20/10/2026, the layout of the cor lisa canvas: the tecido pedidos'
// own list (cards per status that count and filter, a search, "Repetir") and
// "Repetir pedido" — the meters of this time (Igual / Metade / Dobro, 0 leaves
// an item out), a new draft with the prices charged, warned when below
// today's.
runSpec("Pedidos de tecido", async ({ page, test }) => {
  const U = `${Date.now()}`.slice(-6);
  const nomes = { cliente: `Lista ${U}`, tecido: `TecLista${U}` };
  const ids = {};
  const pasta = fs.mkdtempSync(path.join(os.tmpdir(), "neajud-lista-"));

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

  async function corrida(nome) {
    const arquivo = path.join(pasta, `${nome}.tif`);
    execFileSync("convert", ["-size", "60x60", "xc:#a63", arquivo]);
    await page.goto(`${BASE_URL}/arquivos`);
    await page.selectOption('[data-upload-target="tipo"]', "corrida");
    await uploadFileAndWait(page, arquivo);
    const uuid = (await page.locator(".stamp-card").filter({ hasText: nome }).getAttribute("id")).replace(/^arquivo_/, "");
    await postar(`/arquivos/${uuid}/update_client`, { _method: "patch", client_uuid: ids.cliente });
    return uuid;
  }

  async function adicionar(arquivo, metros) {
    const resposta = await page.evaluate(async ({ arquivo, tecido, metros }) => {
      const token = document.querySelector('meta[name="csrf-token"]')?.content || "";
      const campos = { authenticity_token: token, arquivo_uuid: arquivo, materia_prima_uuid: tecido, metros };
      return (await fetch("/pedidos/adicionar_item", { method: "POST", headers: { Accept: "application/json" }, body: new URLSearchParams(campos) })).json();
    }, { arquivo, tecido: ids.tecido, metros });
    if (!resposta.ok) throw new Error(`adicionar_item failed: ${resposta.error}`);
    return resposta.pedido_uuid;
  }

  const linha = () => page.locator(`tr[data-pedido="${ids.pedido}"]`);
  const contagem = async (status) => Number(await page.locator(`.tecido-cartao[data-status="${status}"] .tecido-cartao-contagem`).innerText());

  try {
    await test("Setup: a confirmed tecido pedido of two corridas, 12 m and 14 m, on the client's fabric", async () => {
      await page.goto(`${BASE_URL}/arquivos`);
      await postar("/clients", { "client[name]": nomes.cliente, "client[responsible]": "T" });
      ids.cliente = (await buscarJson(`/clients/search?q=${encodeURIComponent(nomes.cliente)}`)).find((c) => c.name === nomes.cliente).id;
      await postar("/materiais/create_grupo", { "grupo_material[nome]": nomes.tecido });
      const grupo = (await buscarJson(`/materiais/grupos?q=${nomes.tecido}`)).find((g) => g.nome === nomes.tecido).id;
      const cor = (await buscarJson("/materiais/cores"))[0].id;
      await postar("/materiais", { "movimento_estoque[client_uuid]": ids.cliente, "movimento_estoque[tipo]": "entrada", "movimento_estoque[grupo_material_uuid]": grupo,
        "movimento_estoque[cor_material_uuid]": cor, "movimento_estoque[largura]": "1.40", "movimento_estoque[gramatura]": "100g", "movimento_estoque[quantidade]": "50" });
      ids.tecido = (await buscarJson(`/materiais/search?q=${nomes.tecido}`))[0].id;
      await postar("/parametros", { _method: "patch", "empresa[preco_impressao_metro_tecido]": "15" });
      const a = await corrida(`lista-a${U}`);
      const b = await corrida(`lista-b${U}`);
      await page.goto(`${BASE_URL}/arquivos`);
      ids.pedido = await adicionar(a, "12");
      if ((await adicionar(b, "14")) !== ids.pedido) throw new Error("Both items should go into the same draft");
      await page.goto(`${BASE_URL}/pedidos/${ids.pedido}/resumo`);
      await page.locator(".pedido-confirmar").click();
      await waitForText(page, "Pedido confirmed.");
    });

    await test("The list counts by status, filters by its card and searches by client", async () => {
      await page.goto(`${BASE_URL}/pedidos`);
      await page.locator(".pedidos-tecido-link").click();
      await page.locator(".tecido-cartao").first().waitFor();
      const confirmados = await contagem("confirmado");
      if (confirmados < 1) throw new Error("The confirmed card should count the pedido");
      if ((await linha().locator("[data-metros]").innerText()) !== "26 m") throw new Error(`The meters read ${await linha().locator("[data-metros]").innerText()}`);
      await page.locator('.tecido-cartao[data-status="confirmado"]').click();
      // Proof of the new page, not the URL: Turbo changes the URL before it
      // renders, and CI counted the old rows (21/10/2026).
      await page.locator('.tecido-cartao[data-status="confirmado"][aria-current="page"]').waitFor();
      if ((await page.locator("tr[data-pedido]").count()) !== confirmados || !(await linha().count())) throw new Error("The card should filter its status");
      await page.locator('.tecido-cartao[data-status="confirmado"]').click();
      await page.locator('.tecido-cartao[aria-current="page"]').waitFor({ state: "detached" });
      if (new URL(page.url()).search.includes("status=")) throw new Error("Clicking the active card again should clear its filter");
      // The search starts from a page loaded whole: after a Turbo visit the
      // list may render twice (its cached preview, then the page), and in CI
      // the term typed into the first went out empty (runs 39532635201,
      // 39663239674: GET ?q= with nothing).
      await page.goto(`${BASE_URL}/pedidos/tecido`);
      await page.fill("#tecido-busca-q", nomes.cliente);
      await page.locator(".tecido-busca button[type=submit]").click();
      // The server echoes the term into the field only on the searched page.
      await page.locator(`#tecido-busca-q[value="${nomes.cliente}"]`).waitFor();
      if ((await page.locator("tr[data-pedido]").count()) !== 1 || !(await linha().count())) throw new Error("The search should find the client's pedido only");
    });

    await test("Repetir: Dobro on one item, 0 on the other, makes a draft with the prices charged", async () => {
      await page.goto(`${BASE_URL}/pedidos/tecido?q=${encodeURIComponent(nomes.cliente)}`);
      await linha().locator(".tecido-repetir").click();
      await page.locator(".tecido-repetir-item").first().waitFor();
      const campos = page.locator("[data-repetir-metros-target=campo]");
      if ((await campos.count()) !== 2) throw new Error("One field per item");
      await page.locator(".tecido-repetir-item").first().locator("button", { hasText: "Dobro" }).click();
      if ((await campos.first().inputValue()) !== "24") throw new Error(`Dobro of 12 m reads ${await campos.first().inputValue()}`);
      await page.locator(".tecido-atalhos").first().locator("button", { hasText: "Metade" }).click();
      if ((await campos.nth(1).inputValue()) !== "7") throw new Error(`Metade of 14 m for all reads ${await campos.nth(1).inputValue()}`);
      await campos.first().fill("24");
      await campos.nth(1).fill("0");
      await Promise.all([page.waitForURL((url) => /\/pedidos\/[0-9a-f-]{36}$/.test(url.pathname) && !url.pathname.includes(ids.pedido)), page.locator(".tecido-repetir-criar").click()]);
      await waitForText(page, `Rascunho criado a partir do #${ids.pedido.slice(0, 8)}.`);
      ids.novo = new URL(page.url()).pathname.split("/").pop();
      const itens = page.locator(".pedido-item-tecido");
      if ((await itens.count()) !== 1) throw new Error(`The draft should have one item, got ${await itens.count()}`);
      if ((await itens.first().locator(".pedido-tecido-metros-total").innerText()) !== "24 m") throw new Error("The item should come with 24 m");
      if (await page.locator("[data-preco-abaixo]").count()) throw new Error("The price charged is today's: nothing to warn");
    });

    await test("A price raised since warns the repeated draft, never blocking it", async () => {
      await postar("/parametros", { _method: "patch", "empresa[preco_impressao_metro_tecido]": "20" });
      await page.goto(`${BASE_URL}/pedidos/${ids.novo}`);
      const aviso = (await page.locator("[data-preco-abaixo]").innerText()).trim();
      if (aviso !== "Impressão R$ 15,00/m — abaixo do valor de hoje (R$ 20,00/m)") throw new Error(`The warning reads ${aviso}`);
      await page.locator("[data-precos-abaixo]", { hasText: "1 item com preço abaixo do valor de hoje" }).waitFor();
      if (await page.locator(".pedido-confirmar").isDisabled()) throw new Error("A price below today's never blocks confirming");
    });

    await test("On a phone the list and the repeat screen fit, the table scrolling in its box", async () => {
      await page.setViewportSize({ width: 390, height: 844 });
      for (const url of [`/pedidos/tecido`, `/pedidos/${ids.pedido}/repetir`]) {
        await page.goto(`${BASE_URL}${url}`);
        const [largura, tela] = await page.evaluate(() => [document.documentElement.scrollWidth, window.innerWidth]);
        if (largura > tela) throw new Error(`${url} is ${largura}px wide on a ${tela}px phone`);
      }
    });
  } finally {
    await page.setViewportSize({ width: 1280, height: 900 });
    await postar("/parametros", { _method: "patch", "empresa[preco_impressao_metro_tecido]": "15" }).catch(() => {});
    fs.rmSync(pasta, { recursive: true, force: true });
  }
});
