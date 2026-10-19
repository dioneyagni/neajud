// Etapa 2.7b (decided 17/10/2026): the tecido's prices and minimum meters.
// The dono sets the print per meter and the minimum per item in Parâmetros,
// a client his agreed print on his page; on the pedido each item shows its
// print (and the empresa's fabric) with the starting price beside, the team
// edits them and sees the discount; an item below the minimum is a pendência
// until someone with "aprovar abaixo do mínimo" approves it, and confirming
// writes the prices. Then a cliente final with "valores" open sees what he
// pays and the minimum as his own pendência, which he settles by raising the
// meters — never the starting price nor the approval.
const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");
const { BASE_URL, runSpec } = require("./support/runner");
const { uploadFileAndWait } = require("./support/upload");
const { waitForText } = require("./support/wait");

runSpec("Preços do tecido E2E Tests", async ({ page, test }) => {
  const U = Date.now();
  const nomes = { corrida: `corridapreco${U}`, cliente: `Estamparia ${U}`, grupo: `Viscose${U}` };
  const ana = { email: `anapreco${U}@neajud.test`, provisoria: "provisoria-ana-3", senha: "senha-ana-e2e-3" };
  const ids = {};
  const pasta = fs.mkdtempSync(path.join(os.tmpdir(), "precos-tecido-"));

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

  function cartao(nome) {
    return page.locator(".stamp-card").filter({ hasText: nome });
  }

  async function pedirDoCartao(nome, metros) {
    await cartao(nome).locator(".btn-add-to-order").click();
    const modal = page.locator("dialog.add-to-order-dialog[open]");
    await modal.waitFor({ timeout: 5000 });
    await modal.locator(".add-to-order-metros").fill(metros);
    const [resposta] = await Promise.all([
      page.waitForResponse((r) => r.url().includes("/pedidos/adicionar_item")),
      modal.locator('button:has-text("Adicionar")').click(),
    ]);
    const dados = await resposta.json();
    if (!dados.ok) throw new Error(`Adding ${nome} failed: ${dados.error}`);
    return dados.pedido_uuid;
  }

  // The fabric is chosen on the pedido page (the modal's is a search box).
  async function escolherTecido() {
    await page.locator(".pedido-tecido-material").selectOption(ids.tecido);
    await page.locator(".pedido-pendencia--sem_material").waitFor({ state: "detached", timeout: 10000 });
  }

  // Leaving the field fires the real "change" (see precos-dtf).
  async function preencher(locator, valor) {
    await locator.fill(valor);
    await locator.blur();
  }

  async function esperarTexto(seletor, texto) {
    await page.waitForFunction(([seletor, texto]) => document.querySelector(seletor)?.innerText.trim() === texto, [seletor, texto], { timeout: 10000 });
  }

  function linha(parte) {
    return page.locator(`.pedido-tecido-preco-linha[data-parte="${parte}"]`);
  }

  await test("Setup: a client with a fabric and a corrida, an access, and valores open to him", async () => {
    await page.goto(`${BASE_URL}/arquivos`);
    if (!(await postar("/clients", { "client[name]": nomes.cliente, "client[responsible]": "T" }))) throw new Error("Couldn't create the client");
    ids.cliente = (await buscarJson(`/clients/search?q=${encodeURIComponent(nomes.cliente)}`)).find((c) => c.name === nomes.cliente).id;
    await postar("/materiais/create_grupo", { "grupo_material[nome]": nomes.grupo });
    const grupo = (await buscarJson(`/materiais/grupos?q=${nomes.grupo}`)).find((g) => g.nome === nomes.grupo).id;
    const cor = (await buscarJson("/materiais/cores")).find((c) => c.nome === "Branco")?.id || (await postar("/materiais/create_cor", { "cor_material[nome]": "Branco" }), (await buscarJson("/materiais/cores")).find((c) => c.nome === "Branco").id);
    await postar("/materiais", {
      "movimento_estoque[client_uuid]": ids.cliente, "movimento_estoque[tipo]": "entrada", "movimento_estoque[grupo_material_uuid]": grupo,
      "movimento_estoque[cor_material_uuid]": cor, "movimento_estoque[largura]": "1.50", "movimento_estoque[gramatura]": "120g", "movimento_estoque[quantidade]": "40",
    });
    ids.tecido = (await buscarJson(`/materiais/search?tipo=tecido&q=${nomes.grupo}`))[0]?.id;
    if (!(await postar(`/materiais/${ids.tecido}`, { _method: "patch", "materia_prima[preco_metro]": "20" }))) throw new Error("Couldn't price the fabric");

    await page.selectOption('[data-upload-target="tipo"]', "corrida");
    const arquivo = path.join(pasta, `${nomes.corrida}.tif`);
    execFileSync("convert", ["-size", "60x60", "xc:#36a", arquivo]);
    await uploadFileAndWait(page, arquivo);
    ids.corrida = (await cartao(nomes.corrida).getAttribute("id")).replace(/^arquivo_/, "");
    if (!(await postar(`/arquivos/${ids.corrida}/update_client`, { _method: "patch", client_uuid: ids.cliente }))) throw new Error("Couldn't give the corrida its client");
    if (!(await postar(`/clients/${ids.cliente}/visibilidade`, { _method: "patch", "tipos[valores]": "1" }))) throw new Error("Couldn't open valores to the client");

    await page.goto(`${BASE_URL}/clients/${ids.cliente}`);
    const secao = page.locator("#acesso-ao-sistema");
    await secao.locator("#acesso_nome").fill(`Ana Preço ${U}`);
    await secao.locator("#acesso_email").fill(ana.email);
    await secao.locator("#acesso_senha").fill(ana.provisoria);
    await secao.locator('input[type="submit"][value="Add access"]').click();
    await page.locator(`#acesso-ao-sistema tr.usuario-linha[data-email="${ana.email}"]`).waitFor({ timeout: 10000 });
  });

  await test("The dono sets the print price and the minimum; the client his agreed print", async () => {
    await page.goto(`${BASE_URL}/parametros/edit`);
    await page.fill("#empresa_preco_impressao_metro_tecido", "15");
    await page.fill("#empresa_metragem_minima_tecido", "10");
    await page.click('input[type="submit"][value="Save"]');
    await waitForText(page, "Production parameters saved.");
    if ((await page.inputValue("#empresa_metragem_minima_tecido")) !== "10") throw new Error("The minimum wasn't kept");
    await page.goto(`${BASE_URL}/clients/${ids.cliente}`);
    if ((await page.getAttribute("#cliente-preco-impressao-tecido", "placeholder")) !== "15,00") throw new Error("The client's field doesn't show the dono's price");
    await page.fill("#cliente-preco-impressao-tecido", "12");
    await page.click('#precos-tecido button[type="submit"]');
    await waitForText(page, `${nomes.cliente}'s tecido price saved.`);
  });

  await test("The item shows its print at the client's price, the fabric when the empresa's, and the team edits them", async () => {
    await page.goto(`${BASE_URL}/arquivos`);
    ids.pedido = await pedirDoCartao(nomes.corrida, "4");
    await page.goto(`${BASE_URL}/pedidos/${ids.pedido}/resumo`);
    await escolherTecido();
    if ((await linha("Impressão").locator(".pedido-valores-partida").innerText()).trim() !== "R$ 12,00") throw new Error("The print doesn't start at the client's price");
    if (await linha("Tecido").count()) throw new Error("The client's fabric is charged");
    await page.selectOption("#pedido-dono-tecido", "empresa");
    await linha("Tecido").waitFor({ timeout: 10000 });
    if ((await linha("Tecido").locator(".pedido-valores-partida").innerText()).trim() !== "R$ 20,00") throw new Error("The fabric doesn't start at its material's price");
    await esperarTexto('[data-resumo="total"]', "R$ 128,00");
    await preencher(linha("Impressão").locator('input[name="preco_impressao_metro"]'), "11");
    await esperarTexto('[data-resumo="total"]', "R$ 124,00");
    if ((await page.locator("#valores-tecido .pedido-valores-desconto").innerText()).trim() !== "R$ 4,00") throw new Error("The discount isn't measured");
  });

  await test("Below the minimum it waits for approval, then confirms with its prices written", async () => {
    const pendencia = page.locator(".pedido-pendencia--abaixo_do_minimo");
    if (!(await pendencia.innerText()).includes("abaixo do mínimo: 4 m de 10 m")) throw new Error("No pendência below the minimum");
    await page.click(".pedido-tecido-aprovar-minimo");
    await waitForText(page, "approved below the minimum.");
    if (!(await page.locator(".pedido-tecido-minimo--aprovado").innerText()).includes("aprovado por")) throw new Error("The approval doesn't say who");
    if (await pendencia.count()) throw new Error("The approved item is still a pendência");
    await page.locator(".pedido-confirmar").click();
    await waitForText(page, "Pedido confirmed.");
    await page.goto(`${BASE_URL}/pedidos/${ids.pedido}/resumo`);
    if (await page.locator('.pedido-tecido-precos input[name="preco_impressao_metro"]').count()) throw new Error("A confirmed pedido still edits its prices");
    if ((await linha("Impressão").locator(".pedido-valores-preco").innerText()).trim() !== "R$ 11,00") throw new Error("The confirmed print price wasn't kept");
  });

  await test("A cliente final sees what he pays and settles the minimum by raising his meters", async () => {
    await page.click('.header-user button:has-text("Sign out")');
    await page.waitForURL("**/session/new");
    await page.fill('input[name="email_address"]', ana.email);
    await page.fill('input[name="password"]', ana.provisoria);
    await page.click('input[type="submit"][value="Sign in"]');
    await page.waitForURL("**/senha/edit");
    await page.fill('input[name="nova_senha"]', ana.senha);
    await page.click('input[type="submit"][value="Change password"]');
    await page.waitForURL(/\/pedidos$/);
    await page.goto(`${BASE_URL}/arquivos?tipo=corrida`);
    const pedido = await pedirDoCartao(nomes.corrida, "3");
    await page.goto(`${BASE_URL}/pedidos/${pedido}/resumo`);
    await escolherTecido();
    if ((await page.locator(".pedido-tecido-preco-metro").innerText()).trim() !== "R$ 12,00/m") throw new Error("He doesn't see his price per meter");
    // The starting price, the discount and the approval are the team's (Q2, Q5).
    if (await page.locator(".pedido-valores-partida, .pedido-tecido-aprovar-minimo, .pedido-tecido-precos input").count()) throw new Error("He sees the starting price or may approve");
    const pendencia = page.locator(".pedido-pendencia--abaixo_do_minimo");
    if (!(await pendencia.innerText()).includes("3 m de 10 m") || (await pendencia.locator(".pedido-pendencia-em-analise").count())) throw new Error("The minimum isn't his own pendência");
    await preencher(page.locator(".pedido-tecido-metros"), "10");
    await pendencia.waitFor({ state: "detached", timeout: 10000 });
    await esperarTexto(".pedido-tecido-subtotal-item", "R$ 120,00");
  });

  await test("Cleanup", async () => {
    fs.rmSync(pasta, { recursive: true, force: true });
  });
});
