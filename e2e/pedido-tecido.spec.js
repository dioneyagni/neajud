// Etapa 2.7a (decided 16/10/2026): the tecido pedido. A corrida and a cor
// lisa (in the catálogo) go from their cards into one tecido draft in meters,
// the cor lisa's fabric starting the item; on the page each item's fabric
// shows the owner's balance, a width past the paper warns without blocking,
// the team sets the fabric, meters, width and whose fabric it is, and
// confirming keeps the client. The search finds a cor lisa for an empty
// draft. Then a cliente final orders the corrida into his own draft and
// changes its meters, never its width.
const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");
const { BASE_URL, runSpec } = require("./support/runner");
const { uploadFileAndWait } = require("./support/upload");
const { waitForText } = require("./support/wait");

runSpec("Pedido de tecido E2E Tests", async ({ page, test }) => {
  const U = Date.now();
  const nomes = { corrida: `corrida${U}`, cor: `corlisa${U}`, cliente: `Malharia ${U}`, grupo: `Tricoline${U}` };
  const ana = { email: `anatecido${U}@neajud.test`, provisoria: "provisoria-ana-2", senha: "senha-ana-e2e-2" };
  const ids = {};
  const pasta = fs.mkdtempSync(path.join(os.tmpdir(), "pedido-tecido-"));

  function arquivo(nome, cor) {
    const destino = path.join(pasta, `${nome}.tif`);
    execFileSync("convert", ["-size", "60x60", `xc:${cor}`, destino]);
    return destino;
  }

  function cartao(nome) {
    return page.locator(".stamp-card").filter({ hasText: nome });
  }

  // By the link to its file: a cor lisa's title is the system's name ("Laranja 3"), not the file's.
  function item(nome) {
    return page.locator(".pedido-item-tecido", { has: page.locator(`.pedido-item-titulo a[href$="/arquivos/${ids[nome]}"]`) });
  }

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

  // Opens the card's "Pedido", fills the meters and answers the pedido it went into.
  async function pedirDoCartao(nome, metros) {
    await cartao(nome).locator(".btn-add-to-order").click();
    const modal = page.locator("dialog.add-to-order-dialog[open]");
    await modal.waitFor({ timeout: 5000 });
    // A tecido has no parts nor grade: its meters, on a fabric.
    if (await modal.locator(".add-to-order-grade-input, .add-to-order-qtd-total, .add-to-order-peca").count()) throw new Error("The tecido modal offers a grade or parts");
    if (!(await modal.locator(".add-to-order-material").isVisible())) throw new Error("The tecido modal offers no fabric");
    await modal.locator(".add-to-order-metros").fill(metros);
    const [resposta] = await Promise.all([
      page.waitForResponse((r) => r.url().includes("/pedidos/adicionar_item")),
      modal.locator('button:has-text("Adicionar")').click(),
    ]);
    const dados = await resposta.json();
    if (!dados.ok) throw new Error(`Adding ${nome} failed: ${dados.error}`);
    return dados.pedido_uuid;
  }

  // Leaving the field fires the real "change" (see precos-dtf).
  async function preencher(locator, valor) {
    await locator.fill(valor);
    await locator.blur();
  }

  // Proof the save came back: the panel's figure after the page reloads.
  async function esperarResumo(chave, texto) {
    await page.waitForFunction(([chave, texto]) => document.querySelector(`[data-resumo="${chave}"]`)?.innerText.trim() === texto, [chave, texto], { timeout: 10000 });
  }

  await test("Setup: a client with a 1,80 m fabric in stock, a corrida of his and a cor lisa in the catálogo", async () => {
    await page.goto(`${BASE_URL}/arquivos`);
    if (!(await postar("/clients", { "client[name]": nomes.cliente, "client[responsible]": "T" }))) throw new Error("Couldn't create the client");
    ids.cliente = (await buscarJson(`/clients/search?q=${encodeURIComponent(nomes.cliente)}`)).find((c) => c.name === nomes.cliente).id;
    await postar("/materiais/create_grupo", { "grupo_material[nome]": nomes.grupo });
    const grupo = (await buscarJson(`/materiais/grupos?q=${nomes.grupo}`)).find((g) => g.nome === nomes.grupo).id;
    const cor = (await buscarJson("/materiais/cores")).find((c) => c.nome === "Branco")?.id || (await postar("/materiais/create_cor", { "cor_material[nome]": "Branco" }), (await buscarJson("/materiais/cores")).find((c) => c.nome === "Branco").id);
    await postar("/materiais", {
      "movimento_estoque[client_uuid]": ids.cliente, "movimento_estoque[tipo]": "entrada", "movimento_estoque[grupo_material_uuid]": grupo,
      "movimento_estoque[cor_material_uuid]": cor, "movimento_estoque[largura]": "1.80", "movimento_estoque[gramatura]": "120g", "movimento_estoque[quantidade]": "40",
    });
    ids.tecido = (await buscarJson(`/materiais/search?tipo=tecido&q=${nomes.grupo}`))[0]?.id;
    if (!ids.tecido) throw new Error("The fabric wasn't created");

    for (const [tipo, nome, cor] of [["corrida", nomes.corrida, "#3a6"], ["cor_lisa", nomes.cor, "#EF4123"]]) {
      await page.goto(`${BASE_URL}/arquivos`);
      await page.selectOption('[data-upload-target="tipo"]', tipo);
      await uploadFileAndWait(page, arquivo(nome, cor));
      ids[nome] = (await cartao(nome).getAttribute("id")).replace(/^arquivo_/, "");
      if (!(await postar(`/arquivos/${ids[nome]}/update_client`, { _method: "patch", client_uuid: ids.cliente }))) throw new Error(`Couldn't give ${nome} its client`);
    }
    // The cor lisa's fabric, on its page (Etapa 2.5b): the tecido item starts from it.
    await page.goto(`${BASE_URL}/arquivos/${ids[nomes.cor]}`);
    await page.selectOption("#cor-lisa-material-select", ids.tecido);
    await waitForText(page, "Material of");

    await page.goto(`${BASE_URL}/clients/${ids.cliente}`);
    const secao = page.locator("#acesso-ao-sistema");
    await secao.locator("#acesso_nome").fill(`Ana Tecido ${U}`);
    await secao.locator("#acesso_email").fill(ana.email);
    await secao.locator("#acesso_senha").fill(ana.provisoria);
    await secao.locator('input[type="submit"][value="Add access"]').click();
    await page.locator(`#acesso-ao-sistema tr.usuario-linha[data-email="${ana.email}"]`).waitFor({ timeout: 10000 });
  });

  await test("The corrida and the cor lisa go into one tecido draft, in meters", async () => {
    await page.goto(`${BASE_URL}/arquivos`);
    ids.pedido = await pedirDoCartao(nomes.corrida, "12,5");
    // The cor lisa is in the catálogo: it joins the draft in session.
    if ((await pedirDoCartao(nomes.cor, "3")) !== ids.pedido) throw new Error("The cor lisa went into another pedido");
    await page.goto(`${BASE_URL}/pedidos`);
    const tipo = await page.locator("tr", { has: page.locator(`a[href$="${ids.pedido}"]`) }).locator(".pedido-tipo").innerText();
    if (tipo.trim() !== "Tecido") throw new Error(`The pedido is listed as ${tipo}`);
  });

  await test("Each item shows its fabric with the balance, and a width past the paper only warns", async () => {
    await page.goto(`${BASE_URL}/pedidos/${ids.pedido}/resumo`);
    const material = (await item(nomes.cor).locator(".pedido-tecido-material option:checked").innerText()).trim();
    if (!material.includes(nomes.grupo) || !material.endsWith("saldo 40 m")) throw new Error(`The cor lisa's fabric reads ${material}`);
    if (!(await item(nomes.cor).locator(".pedido-tecido-aviso").innerText()).includes("Mais larga que o papel")) throw new Error("No warning for a 1,80 m fabric");
    // The corrida has no fabric yet: a pendência the client settles.
    if (!(await page.locator(".pedido-pendencia--sem_material").innerText()).includes("sem tecido")) throw new Error("No pendência for the corrida without fabric");
    if ((await page.locator('[data-resumo="metros"]').innerText()).trim() !== "15,5 m") throw new Error("The panel doesn't sum the meters");
  });

  await test("The team sets the fabric, the meters, the width and whose fabric it is", async () => {
    await item(nomes.corrida).locator(".pedido-tecido-material").selectOption(ids.tecido);
    await page.locator(".pedido-pendencia--sem_material").waitFor({ state: "detached", timeout: 10000 });
    await preencher(item(nomes.corrida).locator(".pedido-tecido-metros"), "10");
    await esperarResumo("metros", "13 m");
    await preencher(item(nomes.cor).locator(".pedido-tecido-largura-mm"), "1500");
    await item(nomes.cor).locator(".pedido-tecido-aviso").waitFor({ state: "detached", timeout: 10000 });
    if ((await item(nomes.cor).locator(".pedido-tecido-largura-mm").inputValue()) !== "1500") throw new Error("The width wasn't kept");
    await page.selectOption("#pedido-dono-tecido", "empresa");
    await esperarResumo("dono-tecido", "Da empresa");
  });

  await test("Confirming keeps the client; a confirmed pedido is read only, without stages yet", async () => {
    if ((await page.locator("#pedido-cliente-do-pedido").inputValue()) !== ids.cliente) throw new Error("The pedido didn't take the corrida's client");
    await page.locator(".pedido-confirmar").click();
    await waitForText(page, "Pedido confirmed.");
    await page.goto(`${BASE_URL}/pedidos/${ids.pedido}/resumo`);
    if (await page.locator(".pedido-tecido-form").count()) throw new Error("A confirmed pedido still edits its items");
    if ((await page.locator(".pedido-tecido-largura").first().innerText()).trim() === "—") throw new Error("The confirmed item lost its width");
    // Etapa 2.7c brings the stages.
    if (await page.locator(".pedido-ir-producao a").count()) throw new Error("A tecido pedido offers production stages");
  });

  await test("An empty draft finds the cor lisa by its name and adds it in meters", async () => {
    const resumo = await postar("/pedidos", {});
    await page.goto(resumo);
    await page.locator(".pedido-adicionar-busca-tecido").fill(nomes.cor);
    const achada = page.locator(`.pedido-adicionar-arte[data-arquivo-uuid="${ids[nomes.cor]}"]`);
    await achada.waitFor({ timeout: 5000 });
    await achada.locator("button").click();
    const modal = page.locator("dialog.add-to-order-dialog[open]");
    await modal.locator(".add-to-order-metros").fill("2");
    await modal.locator('button:has-text("Adicionar")').click();
    await esperarResumo("metros", "2 m");
  });

  await test("A cliente final orders his corrida and changes its meters, never its width or client", async () => {
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
    const pedido = await pedirDoCartao(nomes.corrida, "4");
    if (pedido === ids.pedido) throw new Error("He added to a confirmed pedido");
    await page.goto(`${BASE_URL}/pedidos/${pedido}/resumo`);
    await item(nomes.corrida).locator(".pedido-tecido-material").selectOption(ids.tecido);
    await page.locator(".pedido-pendencia--sem_material").waitFor({ state: "detached", timeout: 10000 });
    await preencher(item(nomes.corrida).locator(".pedido-tecido-metros"), "6,5");
    await esperarResumo("metros", "6,5 m");
    // The width and the client are the team's (decided 16/10/2026, D4).
    if (await page.locator(".pedido-tecido-largura-mm, #pedido-cliente-do-pedido").count()) throw new Error("He may set the width or the client");
    if ((await item(nomes.corrida).locator(".pedido-tecido-largura").innerText()).trim() !== "1,8 m") throw new Error("He doesn't see the width");
  });

  await test("Cleanup", async () => {
    fs.rmSync(pasta, { recursive: true, force: true });
  });
});
