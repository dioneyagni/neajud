// Etapa 2.6b1 (decided 13/10/2026): the DTF pedido. An etiqueta goes from its
// card into its client's DTF draft — a calçado arte into another pedido —;
// the page shows each size on the film (copies per row, rows, printed, the
// excess that goes to the client, the meters), a line takes its own extra
// rows, the delivery is set, and confirming keeps the client. Then a cliente
// final of another client orders the etiqueta from the catálogo into his own
// draft and sets its extra rows, without seeing whose it is nor the turn.
const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");
const { BASE_URL, runSpec } = require("./support/runner");
const { testImagePath, ensureTestImage } = require("./support/fixtures");
const { submitUploadAndWait, uploadFileAndWait } = require("./support/upload");
const { waitForText } = require("./support/wait");

runSpec("Pedido DTF E2E Tests", async ({ page, test }) => {
  const U = Date.now();
  const nomes = { etiqueta: `ETQ${U}`, tenis: `tenisdtf${U}`, dono: `Dono DTF ${U}`, leitor: `Leitor DTF ${U}` };
  const ana = { email: `ana${U}@neajud.test`, provisoria: "provisoria-ana-1", senha: "senha-ana-e2e-1" };
  const ids = {};
  // Outside the repo: an "e2e-" prefix would be read as part of the name.
  const pasta = fs.mkdtempSync(path.join(os.tmpdir(), "pedido-dtf-"));

  // A square of lado px at 300 dpi: 200 px = 16,93 mm.
  function etiqueta(numero, rotulo, lado) {
    const destino = path.join(pasta, `${numero}-${nomes.etiqueta} - ${rotulo}.tif`);
    execFileSync("convert", ["-size", `${lado}x${lado}`, "xc:#c33", "-units", "PixelsPerInch", "-density", "300", destino]);
    return destino;
  }

  function cartao(nome) {
    return page.locator(".stamp-card").filter({ hasText: nome });
  }

  async function postar(url, campos) {
    return page.evaluate(async ({ url, campos }) => {
      const token = document.querySelector('meta[name="csrf-token"]')?.content || "";
      return (await fetch(url, { method: "POST", body: new URLSearchParams({ authenticity_token: token, ...campos }) })).ok;
    }, { url, campos });
  }

  async function criarCliente(nome) {
    if (!(await postar("/clients", { "client[name]": nome, "client[responsible]": "T" }))) throw new Error(`Couldn't create ${nome}`);
    return page.evaluate(async (nome) => (await (await fetch(`/clients/search?q=${encodeURIComponent(nome)}`)).json()).find((c) => c.name === nome)?.id, nome);
  }

  // Opens the card's "Pedido", fills the grade and answers the pedido it went into.
  async function pedirDoCartao(nome, preencher) {
    await cartao(nome).locator(".btn-add-to-order").click();
    const modal = page.locator("dialog.add-to-order-dialog[open]");
    await modal.waitFor({ timeout: 5000 });
    await preencher(modal);
    const [resposta] = await Promise.all([
      page.waitForResponse((r) => r.url().includes("/pedidos/adicionar_item")),
      modal.locator('button:has-text("Adicionar")').click(),
    ]);
    const dados = await resposta.json();
    if (!dados.ok) throw new Error(`Adding ${nome} failed: ${dados.error}`);
    return dados.pedido_uuid;
  }

  function linhaP() {
    return page.locator(".pedido-dtf-linha[data-tamanho='P']");
  }

  async function celula(nome) {
    return (await linhaP().locator(`.pedido-dtf-${nome}`).innerText()).trim();
  }

  await test("Setup: an etiqueta P/M and a calçado arte of one client, and another client with an access", async () => {
    ensureTestImage();
    await page.goto(BASE_URL);
    ids.dono = await criarCliente(nomes.dono);
    ids.leitor = await criarCliente(nomes.leitor);
    // Etapa 2.6c: no price, no confirming (e2e/precos-dtf.spec.js covers the prices).
    if (!(await postar("/parametros", { _method: "patch", "empresa[preco_metro_dtf]": "120", "empresa[preco_corte_dtf]": "0,05" }))) throw new Error("Couldn't set the DTF's prices");
    await page.goto(`${BASE_URL}/arquivos`);
    await page.selectOption('[data-upload-target="tipo"]', "dtf");
    await page.setInputFiles('input[type="file"]', [etiqueta(701, "P", 200), etiqueta(702, "M", 300)]);
    await page.locator(".conferencia-grupo").first().waitFor({ timeout: 10000 });
    await submitUploadAndWait(page, 2);
    await page.selectOption('[data-upload-target="tipo"]', "calcado");
    const tenis = path.join(pasta, `${nomes.tenis}.tif`);
    fs.copyFileSync(testImagePath, tenis);
    await uploadFileAndWait(page, tenis);
    for (const nome of [nomes.etiqueta, nomes.tenis]) {
      ids[nome] = (await cartao(nome).getAttribute("id")).replace(/^arquivo_/, "");
      if (!(await postar(`/arquivos/${ids[nome]}/update_client`, { _method: "patch", client_uuid: ids.dono }))) throw new Error(`Couldn't give ${nome} its client`);
    }
    await page.goto(`${BASE_URL}/clients/${ids.leitor}`);
    const secao = page.locator("#acesso-ao-sistema");
    await secao.locator("#acesso_nome").fill(`Ana ${U}`);
    await secao.locator("#acesso_email").fill(ana.email);
    await secao.locator("#acesso_senha").fill(ana.provisoria);
    await secao.locator('input[type="submit"][value="Add access"]').click();
    await page.locator(`#acesso-ao-sistema tr.usuario-linha[data-email="${ana.email}"]`).waitFor({ timeout: 10000 });
  });

  await test("The etiqueta goes into a DTF draft, the calçado arte into another pedido", async () => {
    await page.goto(`${BASE_URL}/arquivos`);
    ids.pedido = await pedirDoCartao(nomes.etiqueta, async (modal) => {
      const tamanhos = await modal.locator(".grade-numero-rotulo").allInnerTexts();
      if (tamanhos.join(",") !== "P,M") throw new Error(`The modal offers ${tamanhos}`);
      // Printed on the film: a DTF has no material to choose.
      if (await modal.locator(".add-to-order-material").isVisible()) throw new Error("The DTF modal offers a material");
      await modal.locator('.add-to-order-grade-input[data-tamanho-nome="P"]').fill("100");
    });
    const calcado = await pedirDoCartao(nomes.tenis, async (modal) => {
      if (!(await modal.locator(".add-to-order-material").isVisible())) throw new Error("The calçado modal lost its material");
      await modal.locator(".add-to-order-qtd-total").fill("2");
    });
    if (calcado === ids.pedido) throw new Error("The calçado arte went into the DTF pedido");
    await page.goto(`${BASE_URL}/pedidos`);
    const tipo = await page.locator("tr", { has: page.locator(`a[href$="${ids.pedido}"]`) }).locator(".pedido-tipo").innerText();
    if (tipo.trim() !== "DTF") throw new Error(`The pedido is listed as ${tipo}`);
  });

  await test("The pedido shows the size on the film: the last row completed, the excess to the client", async () => {
    await page.goto(`${BASE_URL}/pedidos/${ids.pedido}/resumo`);
    // Named from its file like a calçado arte (decided 14/10/2026): "DTF-n · ETQ…".
    const titulo = (await page.locator(".pedido-item-dtf .pedido-item-titulo strong").first().innerText()).trim();
    if (!new RegExp(`^DTF-\\d+ · ${nomes.etiqueta}$`).test(titulo)) throw new Error(`The etiqueta is titled ${titulo}`);
    // P: 16,93 mm square → 31 a row (571,5 / 18,43), 100 → 4 rows → 124, 73,7 mm.
    const valores = [await celula("por-fileira"), await celula("fileiras"), await celula("impressas"), await celula("excedente"), await celula("metros")];
    if (valores.join(" | ") !== "31 | 4 | 124 | +24 | 0,074 m") throw new Error(`The P line reads ${valores.join(" | ")}`);
    if ((await page.locator('[data-resumo="impressas"]').innerText()).trim() !== "124") throw new Error("The panel doesn't sum the printed");
    // A line no one ordered shows no fit: nothing goes to the film for it.
    if (await page.locator(".pedido-dtf-linha[data-tamanho='M'] .pedido-dtf-impressas").count()) throw new Error("The M line, not ordered, has a fit");
  });

  await test("A line takes its own extra rows, the pedido its delivery and default", async () => {
    await linhaP().locator('input[name="fileiras_extras"]').fill("1");
    // Leaving the field fires the real "change" (a synthetic one saves it twice; see precos-dtf).
    await linhaP().locator('input[name="fileiras_extras"]').blur();
    await waitForText(page, "Extra rows of P: 1.");
    if ((await celula("impressas")) !== "155") throw new Error(`With 1 extra row the P prints ${await celula("impressas")}`);
    await page.selectOption("#pedido-dtf-entrega", "cortada");
    await waitForText(page, "Pedido updated.");
    if ((await page.locator('[data-resumo="entrega"]').innerText()).trim() !== "Cortada") throw new Error("The delivery wasn't kept");
  });

  await test("Confirming keeps the client and the quantities on the film", async () => {
    if ((await page.locator("#pedido-cliente-do-pedido").inputValue()) !== ids.dono) throw new Error("The pedido didn't take the etiqueta's client");
    // The runner accepts the confirmation dialog.
    await page.locator(".pedido-confirmar").click();
    await waitForText(page, "Pedido confirmed.");
    await page.goto(`${BASE_URL}/pedidos/${ids.pedido}/resumo`);
    if ((await celula("impressas")) !== "155") throw new Error("The confirmed pedido lost its fit");
    if (await page.locator('.pedido-dtf-linha input[name="fileiras_extras"]').count()) throw new Error("A confirmed pedido still edits its extra rows");
  });

  await test("Another client's person orders it from the catálogo into his own draft and sets its extra rows", async () => {
    await page.goto(`${BASE_URL}/arquivos/${ids[nomes.etiqueta]}`);
    await page.locator("#tipo-da-arte-no-catalogo").check();
    await waitForText(page, "is in the catálogo: every client sees it.");
    await page.goto(`${BASE_URL}/pedidos`);
    await page.click('.header-user button:has-text("Sign out")');
    await page.waitForURL("**/session/new");
    await page.fill('input[name="email_address"]', ana.email);
    await page.fill('input[name="password"]', ana.provisoria);
    await page.click('input[type="submit"][value="Sign in"]');
    await page.waitForURL("**/senha/edit");
    await page.fill('input[name="nova_senha"]', ana.senha);
    await page.click('input[type="submit"][value="Change password"]');
    await page.waitForURL(/\/pedidos$/);
    await page.goto(`${BASE_URL}/arquivos?tipo=dtf`);
    const pedido = await pedirDoCartao(nomes.etiqueta, async (modal) => {
      // The catálogo's work never says whose it is (Etapa 2.5a).
      if ((await modal.innerText()).includes(nomes.dono)) throw new Error("The modal shows the etiqueta's owner");
      await modal.locator('.add-to-order-grade-input[data-tamanho-nome="M"]').fill("10");
    });
    if (pedido === ids.pedido) throw new Error("He added to the other client's pedido");
    await page.goto(`${BASE_URL}/pedidos/${pedido}/resumo`);
    const corpo = await page.locator("body").innerText();
    if (!corpo.includes(nomes.leitor)) throw new Error("His pedido isn't his client's");
    // The fit's turn and the client choice are the team's (D4, D5).
    if (corpo.includes(nomes.dono) || corpo.includes("girada") || (await page.locator("#pedido-cliente-do-pedido").count())) throw new Error("He sees the owner, the turn or the client choice");
    await page.fill("#pedido-dtf-fileiras-extras", "1");
    await page.locator("#pedido-dtf-fileiras-extras").blur();
    await waitForText(page, "Pedido updated.");
    if ((await page.locator("#pedido-dtf-fileiras-extras").inputValue()) !== "1") throw new Error("His extra rows weren't kept");
  });

  await test("Cleanup", async () => {
    fs.rmSync(pasta, { recursive: true, force: true });
  });
});
