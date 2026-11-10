// Dublagem 5a (decided 03-04/11/2026): an item dubbed before the estampa
// takes its dublado from the stock at confirmation; what is missing waits
// ("Aguardando: dublagem") and shows on the Dublagens page, em aberto, with
// the components the stock doesn't cover. The operator generates an ordem,
// may cancel it (the stock untouched) and marks it done with the real
// meters: the layers and the ligante go out, the dublado comes in, and the
// pedido stops waiting.
const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");
const { BASE_URL, runSpec } = require("./support/runner");
const { uploadFileAndWait } = require("./support/upload");
const { waitForText } = require("./support/wait");

runSpec("Dublagens E2E Tests", async ({ page, test }) => {
  const U = `${Date.now()}`.slice(-6);
  const gramatura = `${U}g`;
  const nomes = { cliente: `Dublagem ${U}`, corrida: `dublagem${U}`, lona: `Lona-Bege-1.40 m-${gramatura}`, construcao: "Oxford Bege / Lona Bege-1.40 m" };
  const ids = {};

  async function postar(url, campos) {
    return page.evaluate(async ({ url, campos }) => {
      const token = document.querySelector('meta[name="csrf-token"]')?.content || "";
      const corpo = new URLSearchParams({ authenticity_token: token });
      for (const [chave, valor] of Object.entries(campos)) corpo.append(chave, valor);
      const resposta = await fetch(url, { method: "POST", body: corpo });
      return resposta.ok ? resposta.url : null;
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
    await postar(`/grupos-de-material/${uuid}`, {
      _method: "patch", "grupo_material[superficie]": papeis.superficie ? "1" : "0", "grupo_material[base]": papeis.base ? "1" : "0",
      "grupo_material[estampavel]": "nao", "pede[]": pede, "obrigatorios[]": pede,
    });
    return uuid;
  }

  // An entry of the empresa's stock; the material's uuid, its type and price set.
  async function material(grupoUuid, nome, metros, campos, tipo, preco) {
    const ok = await postar("/movimentos", {
      "movimento_estoque[da_empresa]": "true", "movimento_estoque[tipo]": "entrada", "movimento_estoque[quantidade]": metros,
      "movimento_estoque[grupo_material_uuid]": grupoUuid, "movimento_estoque[cor_material_uuid]": ids.cor, "movimento_estoque[largura]": "1.40 m", ...campos,
    });
    if (!ok) throw new Error(`The entry of ${nome} failed`);
    const encontrado = (await buscarJson(`/materiais/search?q=${encodeURIComponent(nome.split(/[- ]/)[0])}`)).find((m) => m.nome_completo === nome);
    if (!encontrado) throw new Error(`${nome} wasn't registered`);
    await postar(`/materiais/${encontrado.id}`, { _method: "patch", "materia_prima[tipo]": tipo, "materia_prima[preco_metro]": preco });
    return encontrado.id;
  }

  // Each change of the item's form saves and Turbo renders the pedido
  // again, swapping the body: mark the old one and wait for the new.
  async function salvarItem(acao) {
    await page.evaluate(() => { document.body.dataset.antigo = "1"; });
    await acao();
    await page.locator("body:not([data-antigo])").waitFor({ state: "attached" });
  }

  async function aguardando() {
    await page.goto(`${BASE_URL}/pedidos/${ids.pedido}/resumo`);
    const linha = page.locator('[data-resumo="aguardando"]');
    return (await linha.count()) ? (await linha.innerText()).replace(/\s+/g, " ").trim() : null;
  }

  async function abrirDublagens() {
    await page.goto(`${BASE_URL}/materiais`);
    await page.locator("a.materiais-dublagens-link").click();
    await page.locator(".dublagens-pagina h2").waitFor();
  }

  const aberta = () => page.locator(`[data-dublagem-aberta][data-construcao="${ids.construcao}"]`);
  const gerada = () => page.locator(`#dublagens-geradas [data-construcao="${ids.construcao}"]`);

  await test("Setup: Oxford over Lona with filme 35 µm, 5 m of Lona only, and a client's corrida", async () => {
    await page.goto(`${BASE_URL}/materiais`);
    await postar("/materiais/create_cor", { "cor_material[nome]": "Bege" });
    ids.cor = (await buscarJson("/materiais/cores")).find((c) => c.nome === "Bege").id;
    const oxford = await material(await grupo("Oxford"), `Oxford-Bege-1.40 m-${gramatura}`, "30", { "movimento_estoque[gramatura]": gramatura }, "tecido", "20");
    const lona = await material(await grupo("Lona", { base: true }, ["gramatura"]), nomes.lona, "5", { "movimento_estoque[gramatura]": gramatura }, "tecido", "10");
    const filme = await material(await grupo("Filme", {}, ["micras"]), "Filme 35 µm-Bege-1.40 m", "30", { "movimento_estoque[micras]": "35" }, "filme", "3");
    const salva = await postar("/construcoes", {
      // Dublagem 5b1a: one card of the chave, Oxford over Lona.
      "construcao[situacao]": "", "construcao[preco_final]": "46", "construcao[dublagens][0][cima][escolha]": oxford, "construcao[dublagens][0][cima][lado]": "trama",
      "construcao[dublagens][0][baixo][escolha]": lona, "construcao[dublagens][0][ligante_uuid]": filme,
    });
    ids.construcao = salva?.match(/construcoes\/([^/]+)\/edit/)?.[1];
    if (!ids.construcao) throw new Error(`The construção wasn't saved (${salva})`);
    await postar("/parametros", { _method: "patch", "empresa[preco_impressao_metro_tecido]": "15" });

    await postar("/clients", { "client[name]": nomes.cliente, "client[responsible]": "T" });
    ids.cliente = (await buscarJson(`/clients/search?q=${encodeURIComponent(nomes.cliente)}`)).find((c) => c.name === nomes.cliente).id;
    const pasta = fs.mkdtempSync(path.join(os.tmpdir(), "dublagens-"));
    const arquivo = path.join(pasta, `${nomes.corrida}.tif`);
    execFileSync("convert", ["-size", "60x60", "xc:#3a6", arquivo]);
    await page.goto(`${BASE_URL}/arquivos`);
    await page.selectOption('[data-upload-target="tipo"]', "corrida");
    await uploadFileAndWait(page, arquivo);
    fs.rmSync(pasta, { recursive: true, force: true });
    ids.corrida = (await page.locator(".stamp-card").filter({ hasText: nomes.corrida }).getAttribute("id")).replace(/^arquivo_/, "");
    await postar(`/arquivos/${ids.corrida}/update_client`, { _method: "patch", client_uuid: ids.cliente });
    ids.oxford = oxford;
  });

  await test("Confirmed with the construção, the pedido takes the dublado and waits for its dublagem", async () => {
    const resposta = await page.evaluate(async ({ corrida, oxford }) => {
      const token = document.querySelector('meta[name="csrf-token"]')?.content || "";
      const campos = { authenticity_token: token, arquivo_uuid: corrida, materia_prima_uuid: oxford, metros: "12" };
      const r = await fetch("/pedidos/adicionar_item", { method: "POST", headers: { Accept: "application/json" }, body: new URLSearchParams(campos) });
      return r.json();
    }, { corrida: ids.corrida, oxford: ids.oxford });
    if (!resposta.ok) throw new Error(`adicionar_item failed: ${resposta.error}`);
    ids.pedido = resposta.pedido_uuid;
    await page.goto(`${BASE_URL}/pedidos/${ids.pedido}/resumo`);
    await salvarItem(() => page.selectOption(".pedido-tecido-construcao", ids.construcao));
    const producao = (await page.locator("[data-dublagem-producao]").innerText()).trim();
    if (producao !== "o dublado sai do estoque (Dublagens)") throw new Error(`The item says ${producao}`);
    await page.locator(".pedido-confirmar").click();
    await waitForText(page, "Pedido confirmed.");

    const linha = await aguardando();
    if (linha !== `Aguardando: dublagem de ${nomes.construcao} · faltam 12 m`) throw new Error(`The panel reads ${linha}`);
    await page.goto(`${BASE_URL}/pedidos/tecido?aguardando=1`);
    const selo = (await page.locator(`[data-aguardando]`).first().innerText()).trim();
    if (selo !== "aguardando dublagem") throw new Error(`The list's badge reads ${selo}`);
    await page.goto(`${BASE_URL}/pedidos/${ids.pedido}/tecido/producao/calandra`);
    const calandra = (await page.locator("[data-aguardando-dublagem]").innerText()).trim();
    if (calandra !== "aguardando dublagem: 12 m") throw new Error(`The Calandra's line reads ${calandra}`);
  });

  await test("Dublagens lists it em aberto, with the pedido and the Lona the stock doesn't cover", async () => {
    await abrirDublagens();
    const texto = (await aberta().innerText()).replace(/\s+/g, " ");
    if (!texto.includes("Faltam 12 m")) throw new Error(`Em aberto reads ${texto}`);
    if ((await aberta().locator(`.dublagem-pedidos a[href="/pedidos/${ids.pedido}/resumo"]`).count()) !== 1) throw new Error("The pedido isn't linked");
    const falta = (await aberta().locator("[data-falta-componente]").innerText()).trim();
    if (!falta.includes(`${nomes.lona} da empresa, 7 m`)) throw new Error(`The warning reads ${falta}`);
  });

  await test("An ordem of part of it leaves the rest em aberto; cancelled, it all comes back", async () => {
    await aberta().locator(".dublagem-metros-campo").fill("5");
    await aberta().locator('input[type="submit"][value="Gerar ordem"]').click();
    await waitForText(page, `gerada: 5 m de ${nomes.construcao}.`);
    if (!(await aberta().innerText()).includes("5 m já em ordem")) throw new Error("Em aberto doesn't count the ordem");
    if ((await aberta().locator("[data-falta]").innerText()).trim() !== "7 m") throw new Error("Em aberto should miss the other 7 m");

    // The confirm ("O estoque não muda.") is accepted by the runner.
    await gerada().locator(".dublagem-cancelar").click();
    await waitForText(page, "cancelada.");
    if ((await gerada().count()) !== 0) throw new Error("The cancelled ordem is still generated");
    if ((await aberta().locator("[data-falta]").innerText()).trim() !== "12 m") throw new Error("Cancelled, the 12 m should be em aberto again");
  });

  await test("Generated and done with the real meters: components out, the dublado in, the pedido no longer waits", async () => {
    await aberta().locator(".dublagem-metros-campo").fill("15");
    await aberta().locator('input[type="submit"][value="Gerar ordem"]').click();
    await waitForText(page, `gerada: 15 m de ${nomes.construcao}.`);
    if ((await aberta().count()) !== 0) throw new Error("A generated ordem covering it leaves nothing em aberto");
    ids.ordem = await gerada().getAttribute("data-ordem");

    await gerada().locator(".dublagem-metros-campo").fill("14");
    await gerada().locator('input[type="submit"][value="Marcar feita"]').click();
    await waitForText(page, `feita: entraram 14 m de ${nomes.construcao}.`);
    if ((await page.locator(`#dublagens-feitas [data-ordem="${ids.ordem}"]`).count()) !== 1) throw new Error("The ordem isn't listed as done");
    if (await aguardando()) throw new Error("The dublado came in: the pedido should not wait");

    await page.goto(`${BASE_URL}/movimentos`);
    const linhas = (await page.locator(`tr:has([data-ordem-dublagem="${ids.ordem}"])`).allInnerTexts()).map((l) => l.replace(/\s+/g, " "));
    const esperado = [`${nomes.lona} Out 14 m`, `Filme 35 µm-Bege-1.40 m Out 14 m`, `Oxford-Bege-1.40 m-${gramatura} Out 14 m`, `${nomes.construcao} In 14 m`];
    for (const trecho of esperado) if (!linhas.some((l) => l.includes(trecho))) throw new Error(`No movement "${trecho}": ${linhas.join(" | ")}`);
    if (linhas.length !== 4) throw new Error(`${linhas.length} movements for the ordem: ${linhas.join(" | ")}`);
  });
});
