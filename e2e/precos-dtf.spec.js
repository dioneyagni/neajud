// Etapa 2.6c (decided 13-14/10/2026): charging the DTF. The dono sets the
// price per meter and per unit cut in Parâmetros; the etiqueta shows each
// size's calculated unit price and takes an agreed one over it; a client has
// his own price per meter; in the pedido the team edits a line's price (the
// starting one beside it, the discount measured), switches to charging by
// meter, and confirms.
const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");
const { BASE_URL, runSpec } = require("./support/runner");
const { submitUploadAndWait } = require("./support/upload");
const { waitForText } = require("./support/wait");

runSpec("Preços DTF E2E Tests", async ({ page, test }) => {
  const U = Date.now();
  const nomes = { etiqueta: `PRC${U}`, cliente: `Cliente Preco ${U}` };
  const ids = {};
  // Outside the repo: an "e2e-" prefix would be read as part of the name.
  const pasta = fs.mkdtempSync(path.join(os.tmpdir(), "precos-dtf-"));

  function cartao() {
    return page.locator(".stamp-card").filter({ hasText: nomes.etiqueta });
  }

  async function postar(url, campos) {
    return page.evaluate(async ({ url, campos }) => {
      const token = document.querySelector('meta[name="csrf-token"]')?.content || "";
      return (await fetch(url, { method: "POST", body: new URLSearchParams({ authenticity_token: token, ...campos }) })).ok;
    }, { url, campos });
  }

  async function texto(seletor) {
    return (await page.locator(seletor).first().innerText()).trim();
  }

  // Types into an auto-submitting field and waits for the page it redirects to.
  // Types and leaves the field, like a person: a synthetic "change" left the
  // field dirty, so a later blur (the morph, a resize) fired a real one and
  // saved it again — its notice replaced the next step's (headed run, 14/10/2026).
  async function digitar(seletor, valor, aviso) {
    await page.fill(seletor, valor);
    await page.locator(seletor).blur();
    await waitForText(page, aviso);
  }

  await test("Setup: a client and an etiqueta of his (P: 200 px at 300 dpi, 16,93 mm)", async () => {
    await page.goto(BASE_URL);
    if (!(await postar("/clients", { "client[name]": nomes.cliente, "client[responsible]": "T" }))) throw new Error("Couldn't create the client");
    ids.cliente = await page.evaluate(async (nome) => (await (await fetch(`/clients/search?q=${encodeURIComponent(nome)}`)).json()).find((c) => c.name === nome)?.id, nomes.cliente);
    const arquivo = path.join(pasta, `801-${nomes.etiqueta} - P.tif`);
    execFileSync("convert", ["-size", "200x200", "xc:#36c", "-units", "PixelsPerInch", "-density", "300", arquivo]);
    await page.goto(`${BASE_URL}/arquivos`);
    await page.selectOption('[data-upload-target="tipo"]', "dtf");
    await page.setInputFiles('input[type="file"]', [arquivo]);
    await submitUploadAndWait(page, 1);
    await page.selectOption('[data-upload-target="tipo"]', "calcado");
    ids.etiqueta = (await cartao().getAttribute("id")).replace(/^arquivo_/, "");
    if (!(await postar(`/arquivos/${ids.etiqueta}/update_client`, { _method: "patch", client_uuid: ids.cliente }))) throw new Error("Couldn't give the etiqueta its client");
  });

  await test("The dono sets the DTF's price per meter and per unit cut in Parâmetros", async () => {
    await page.goto(`${BASE_URL}/parametros/edit`);
    await page.fill("#empresa_preco_metro_dtf", "120");
    await page.fill("#empresa_preco_corte_dtf", "0,05");
    await page.click('input[type="submit"][value="Save"]');
    await waitForText(page, "Production parameters saved.");
  });

  await test("The etiqueta shows its calculated unit price and takes an agreed one over it", async () => {
    await page.goto(`${BASE_URL}/arquivos/${ids.etiqueta}`);
    // 31 a row every 18,43 mm → 1682 a meter; 120 / 1682 = 0,071 → R$ 0,08 (rounded up).
    if ((await texto(".arte-arquivo-preco-calculado")) !== "calculado R$ 0,08") throw new Error(`Calculated: ${await texto(".arte-arquivo-preco-calculado")}`);
    await digitar('.arte-preco-form input[name="preco_unidade_combinado"]', "0,10", "Unit price of P: agreed.");
    if ((await page.inputValue('.arte-preco-form input[name="preco_unidade_combinado"]')) !== "0,10") throw new Error("The agreed price wasn't kept");
  });

  await test("A client has his own price per meter, on his page", async () => {
    await page.goto(`${BASE_URL}/clients/${ids.cliente}`);
    await page.fill("#cliente-preco-metro-dtf", "150");
    await page.click('#precos-dtf button[type="submit"]');
    await waitForText(page, "DTF prices saved.");
    if ((await page.inputValue("#cliente-preco-metro-dtf")) !== "150,00") throw new Error("The client's price wasn't kept");
  });

  await test("In the pedido the team edits a line's price; the starting one stays beside it", async () => {
    await page.goto(`${BASE_URL}/arquivos`);
    await cartao().locator(".btn-add-to-order").click();
    const modal = page.locator("dialog.add-to-order-dialog[open]");
    await modal.locator('.add-to-order-grade-input[data-tamanho-nome="P"]').fill("100");
    const [resposta] = await Promise.all([
      page.waitForResponse((r) => r.url().includes("/pedidos/adicionar_item")),
      modal.locator('button:has-text("Adicionar")').click(),
    ]);
    ids.pedido = (await resposta.json()).pedido_uuid;
    await page.goto(`${BASE_URL}/pedidos/${ids.pedido}/resumo`);
    // 100 ordered → 4 rows of 31 = 124 printed, the excess charged: 124 × the agreed 0,10.
    // The line's price sits in its etiqueta's table (decided 14/10/2026).
    const linha = ".pedido-item-dtf .pedido-dtf-linha[data-tamanho='P']";
    if ((await texto(`${linha} .pedido-valores-partida`)) !== "0,10") throw new Error(`Starting price: ${await texto(`${linha} .pedido-valores-partida`)}`);
    if ((await texto(`${linha} .pedido-valores-subtotal`)) !== "R$ 12,40") throw new Error(`Subtotal: ${await texto(`${linha} .pedido-valores-subtotal`)}`);
    await digitar(`${linha} input[name="preco_unidade"]`, "0,09", "Unit price of P: edited.");
    if ((await texto(`${linha} .pedido-valores-subtotal`)) !== "R$ 11,16") throw new Error("The edited price didn't charge");
    if ((await texto("#valores-dtf .pedido-valores-desconto")) !== "R$ 1,24") throw new Error(`Discount: ${await texto("#valores-dtf .pedido-valores-desconto")}`);
    // "Valores do pedido" sums the etiquetas, never repeating a size; the panel shows the total.
    const partes = await page.locator("#valores-dtf .pedido-valores-linha").evaluateAll((trs) => trs.map((tr) => tr.dataset.parte));
    if (partes.join() !== "Etiquetas") throw new Error(`Valores do pedido lists ${partes.join()}`);
    if ((await texto('[data-resumo="total"]')) !== "R$ 11,16") throw new Error(`The panel's total: ${await texto('[data-resumo="total"]')}`);
  });

  await test("On a phone each size is a block: its cells labelled, nothing wider than the card", async () => {
    // Headed runs have no fixed viewport (null): come back to a desktop one.
    const antes = page.viewportSize() || { width: 1280, height: 720 };
    await page.setViewportSize({ width: 390, height: 844 });
    try {
      const bloco = await page.locator(".pedido-item-dtf .pedido-dtf-linha[data-tamanho='P']").evaluate((tr) => ({
        display: getComputedStyle(tr).display,
        rotulo: getComputedStyle(tr.querySelector(".pedido-valores-preco"), "::before").content,
      }));
      if (bloco.display !== "grid" || bloco.rotulo !== '"Preço un."') throw new Error(`The P line on a phone: ${JSON.stringify(bloco)}`);
      const larga = await page.locator(".pedido-item-dtf .pedido-dtf-tabela-wrap").evaluate((wrap) => wrap.scrollWidth > wrap.clientWidth);
      if (larga) throw new Error("The etiqueta's table is wider than its card on a phone");
    } finally {
      await page.setViewportSize(antes);
    }
  });

  await test("Charged by meter, the film at the client's price; confirming writes it", async () => {
    await page.selectOption("#pedido-cobranca-dtf", "metro");
    await waitForText(page, "Pedido's prices updated.");
    const filme = "#valores-dtf .pedido-valores-linha[data-parte='Filme']";
    if ((await texto(`${filme} .pedido-valores-partida`)) !== "R$ 150,00") throw new Error(`The film's price: ${await texto(`${filme} .pedido-valores-partida`)}`);
    await page.locator(".pedido-confirmar").click();
    await waitForText(page, "Pedido confirmed.");
    await page.goto(`${BASE_URL}/pedidos/${ids.pedido}/resumo`);
    if ((await texto(`${filme} .pedido-valores-preco`)) !== "R$ 150,00") throw new Error("The confirmed pedido lost its price");
    if (await page.locator("#valores-dtf input").count()) throw new Error("A confirmed pedido still edits its prices");
  });

  await test("Cleanup", async () => {
    fs.rmSync(pasta, { recursive: true, force: true });
  });
});
