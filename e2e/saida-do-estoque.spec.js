const path = require("path");
const fs = require("fs");
const os = require("os");
const { execFileSync } = require("child_process");
const { uploadFileAndWait } = require("./support/upload");
const { waitForText } = require("./support/wait");
const { BASE_URL, runSpec } = require("./support/runner");

// Etapa 2.3d2 (decided 19/10/2026): confirming takes the pedido's expected
// meters from the stock — the fabric from its owner, the paper from the
// empresa — and a pedido whose out passes what came in waits for material,
// oldest outs covered first; an entry clears it. Never blocks.
runSpec("Saída do estoque", async ({ page, test }) => {
  const U = `${Date.now()}`.slice(-6);
  const nomes = { cliente: `Saida ${U}`, tecido: `TecSaida${U}`, papel: `PapSaida${U}`, corrida: `saida${U}` };
  const ids = {};
  const pasta = fs.mkdtempSync(path.join(os.tmpdir(), "neajud-saida-"));

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
  async function entrada(grupo, largura, metros, cliente) {
    await postar("/materiais/create_grupo", { "grupo_material[nome]": grupo });
    const grupoUuid = (await buscarJson(`/materiais/grupos?q=${grupo}`)).find((g) => g.nome === grupo).id;
    const cor = (await buscarJson("/materiais/cores"))[0].id;
    const dono = cliente ? { "movimento_estoque[client_uuid]": cliente } : { "movimento_estoque[da_empresa]": "1" };
    await postar("/materiais", { ...dono, "movimento_estoque[tipo]": "entrada", "movimento_estoque[grupo_material_uuid]": grupoUuid, "movimento_estoque[cor_material_uuid]": cor,
      "movimento_estoque[largura]": largura, "movimento_estoque[gramatura]": "100g", "movimento_estoque[quantidade]": metros });
    return (await buscarJson(`/materiais/search?q=${grupo}`))[0].id;
  }

  async function aguardando() {
    await page.goto(`${BASE_URL}/pedidos/${ids.pedido}/resumo`);
    const linha = page.locator('[data-resumo="aguardando"]');
    return (await linha.count()) ? (await linha.innerText()).trim() : null;
  }

  async function listadosAguardando() {
    await page.goto(`${BASE_URL}/pedidos?aguardando=1`);
    return page.locator(`tr:has(a[href$="/pedidos/${ids.pedido}"]) [data-aguardando]`).count();
  }

  try {
    await test("Setup: a client with 5 m of his fabric, a paper of the empresa and a corrida of his", async () => {
      await page.goto(`${BASE_URL}/arquivos`);
      await postar("/clients", { "client[name]": nomes.cliente, "client[responsible]": "T" });
      ids.cliente = (await buscarJson(`/clients/search?q=${encodeURIComponent(nomes.cliente)}`)).find((c) => c.name === nomes.cliente).id;
      ids.tecido = await entrada(nomes.tecido, "1.40", "5", ids.cliente);
      ids.papel = await entrada(nomes.papel, "1.60", "100");
      await postar(`/materiais/${ids.papel}`, { _method: "patch", "materia_prima[tipo]": "papel" });
      await postar(`/materiais/${ids.tecido}`, { _method: "patch", "materia_prima[preco_metro]": "20" });
      // Etapa 2.7b: no price, no confirming.
      await postar("/parametros", { _method: "patch", "empresa[preco_impressao_metro_tecido]": "15" });

      const arquivo = path.join(pasta, `${nomes.corrida}.tif`);
      execFileSync("convert", ["-size", "60x60", "xc:#3a6", arquivo]);
      await page.goto(`${BASE_URL}/arquivos`);
      await page.selectOption('[data-upload-target="tipo"]', "corrida");
      await uploadFileAndWait(page, arquivo);
      ids.corrida = (await page.locator(".stamp-card").filter({ hasText: nomes.corrida }).getAttribute("id")).replace(/^arquivo_/, "");
      await postar(`/arquivos/${ids.corrida}/update_client`, { _method: "patch", client_uuid: ids.cliente });
    });

    await test("A tecido pedido of 12 m (past the 10 m minimum precos-tecido leaves set) on his fabric, printed on the empresa's paper", async () => {
      const resposta = await page.evaluate(async ({ corrida, tecido }) => {
        const token = document.querySelector('meta[name="csrf-token"]')?.content || "";
        const campos = { authenticity_token: token, arquivo_uuid: corrida, materia_prima_uuid: tecido, metros: "12" };
        const r = await fetch("/pedidos/adicionar_item", { method: "POST", headers: { Accept: "application/json" }, body: new URLSearchParams(campos) });
        return r.json();
      }, { corrida: ids.corrida, tecido: ids.tecido });
      if (!resposta.ok) throw new Error(`adicionar_item failed: ${resposta.error}`);
      ids.pedido = resposta.pedido_uuid;
      await page.goto(`${BASE_URL}/pedidos/${ids.pedido}/resumo`);
      await page.selectOption("#pedido-material-impressao", ids.papel);
      await page.locator('[data-resumo="material-impressao"]', { hasText: nomes.papel }).waitFor({ timeout: 10000 });
      if (await aguardando()) throw new Error("A draft took nothing from the stock: it can't wait yet");
    });

    await test("Confirming takes the fabric from the client and the paper from the empresa, listed with the pedido", async () => {
      await page.locator(".pedido-confirmar").click();
      await waitForText(page, "Pedido confirmed.");
      await page.goto(`${BASE_URL}/movimentos`);
      const saidas = await page.locator(`tr:has([data-pedido="${ids.pedido}"] a)`).allInnerTexts();
      const resumo = saidas.map((linha) => linha.replace(/\s+/g, " "));
      if (resumo.length !== 2 || !resumo.some((l) => l.includes(nomes.cliente) && l.includes(nomes.tecido) && l.includes("Out 12 m"))
        || !resumo.some((l) => l.includes("Empresa") && l.includes(nomes.papel) && l.includes("Out 12 m"))) throw new Error(`The pedido's outs: ${resumo.join(" | ")}`);
    });

    await test("Past the 5 m that came in, the pedido waits: on the list, its filter, its panel and on Materials", async () => {
      if ((await listadosAguardando()) !== 1) throw new Error("The filter should list the pedido with its badge");
      const linha = await aguardando();
      if (!linha?.includes(`${nomes.tecido}`) || !linha.includes("do cliente · faltam 7 m")) throw new Error(`The panel reads ${linha}`);
      if (linha.includes(nomes.papel)) throw new Error("The empresa's 100 m of paper cover the 12 m");
      await page.goto(`${BASE_URL}/materiais`);
      const material = (await page.locator(`tr[data-material="${ids.tecido}"] [data-aguardando]`).innerText()).trim();
      if (material !== "Aguardando: 1 pedido · faltam 7 m") throw new Error(`Materials reads ${material}`);
    });

    await test("An entry of the 7 m clears it by itself", async () => {
      await entrada(nomes.tecido, "1.40", "7", ids.cliente);
      if ((await listadosAguardando()) !== 0) throw new Error("The covered pedido should leave the filter");
      if (await aguardando()) throw new Error("The covered pedido's panel should not say it waits");
    });
  } finally {
    fs.rmSync(pasta, { recursive: true, force: true });
  }
});
