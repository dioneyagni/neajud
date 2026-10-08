const path = require("path");
const fs = require("fs");
const os = require("os");
const { execSync } = require("child_process");
const { uploadFileAndWait } = require("./support/upload");
const { waitForQueuedTask } = require("./support/wait");
const { BASE_URL, runSpec } = require("./support/runner");
const { modeloOficial } = require("./support/catalogo");

// Etapa 2.2 (2/3 and 3/3; decided 07/10/2026): the factory gives each production
// stage's baixa — one line, a referência or the whole pedido — typing the
// metragem or the pieces; outside the dono's band it warns, and the operator
// corrects or confirms. Estamparia waits for Impressão and Corte;
// Conferência for Estamparia.
runSpec("Produção: etapas e baixas", async ({ page, test }) => {
  const U = `${Date.now()}`.slice(-6);
  const nomes = { cliente: `Baixas ${U}`, molde: `BX${U}`, arte: `20-BAIXA${U}-29_30.tif` };
  const pasta = fs.mkdtempSync(path.join(os.tmpdir(), "neajud-baixas-"));
  let pedidoUuid;

  async function post(url, campos) {
    return page.evaluate(async ({ url, campos }) => {
      const token = document.querySelector('meta[name="csrf-token"]')?.content || "";
      const r = await fetch(url, { method: "POST", headers: { Accept: "application/json" }, body: new URLSearchParams({ authenticity_token: token, ...campos }) });
      return { ok: r.ok, url: r.url, json: await r.json().catch(() => null) };
    }, { url, campos });
  }

  async function buscar(url, chave, valor) {
    return page.evaluate(async ({ url, chave, valor }) => (await (await fetch(url)).json()).find((r) => r[chave] === valor)?.id, { url, chave, valor });
  }

  // Types a measure in a baixa's field and saves; returns what the field says.
  async function darBaixa(baixa, medida) {
    await baixa.locator(".baixa-abrir").click();
    await baixa.locator(".baixa-medida").fill(medida);
    await baixa.locator(".baixa-salvar").click();
  }

  async function salvoERecarregado(acao) {
    await Promise.all([ page.waitForResponse((r) => new URL(r.url()).pathname === `/pedidos/${pedidoUuid}/baixas` && r.status() === 200), acao() ]);
    await page.getByText(/^Baixa de .* registrada/).waitFor();
  }

  try {
    await test("Setup: a confirmed pedido of one arte (Bota, DXF 29-30), 5 pairs of the 30", async () => {
      await page.goto(BASE_URL);
      const bota = await modeloOficial(page, "Bota");
      await post("/clients", { "client[name]": nomes.cliente, "client[responsible]": "T" });
      const clienteUuid = await buscar(`/clients/search?q=${encodeURIComponent(nomes.cliente)}`, "name", nomes.cliente);
      await post("/moldes", { "molde[sufixo]": nomes.molde, "molde[client_uuid]": clienteUuid, "molde[modelo_uuid]": bota.id });
      const moldeUuid = await buscar(`/moldes/search?q=${encodeURIComponent(nomes.molde)}`, "sufixo", nomes.molde);

      const dxf = path.join(pasta, `BX${U}.dxf`);
      fs.copyFileSync(path.join(__dirname, "..", "spec", "fixtures", "files", "29-30.dxf"), dxf);
      await uploadFileAndWait(page, dxf);
      const corteUuid = (await page.locator(".stamp-card").filter({ hasText: `BX${U}` }).first().locator("a").first().getAttribute("href")).split("/").pop();
      await post(`/arquivos/${corteUuid}/organize`, { _method: "patch", modelo_uuid: bota.id, tipo_grade: "par",
        "tamanhos[0][tamanhos]": "30", "tamanhos[0][width_mm]": "150", "tamanhos[0][height_mm]": "250", "tamanhos[0][area_mm2]": "8000" });
      await post(`/arquivos/${corteUuid}/add_molde`, { molde_uuid: moldeUuid });
      await waitForQueuedTask(page, `/arquivos/${corteUuid}/preparacao_tamanhos.json`);

      // A 15,24 cm arte (60 px at 10 DPI): ten across the 1,60 m paper.
      const arte = path.join(pasta, nomes.arte);
      execSync(`convert -size 60x60 xc:orange -units PixelsPerInch -density 10 'TIFF:${arte}'`);
      await uploadFileAndWait(page, arte);
      const arteUuid = (await page.locator(".stamp-card").filter({ hasText: `BAIXA${U}` }).first().locator("a").first().getAttribute("href")).split("/").pop();
      await post(`/arquivos/${arteUuid}/update_molde`, { _method: "patch", molde_uuid: moldeUuid });
      await waitForQueuedTask(page, `/arquivos/${arteUuid}/busca_tamanho.json`);

      const adicionado = await post("/pedidos/adicionar_item", { arquivo_uuid: arteUuid, "grade[30]": "5" });
      if (!adicionado.json?.ok) throw new Error(`adicionar_item failed: ${JSON.stringify(adicionado.json)}`);
      pedidoUuid = adicionado.json.pedido_uuid;
      // Confirming redirects to the pedidos list (HTML only): the proof is the
      // pedido's badge, not the answer.
      await post(`/pedidos/${pedidoUuid}/confirmar`, {});
      await page.goto(`${BASE_URL}/pedidos/${pedidoUuid}/resumo`);
      if ((await page.locator("h2 .badge").innerText()).trim() !== "confirmado") throw new Error("The pedido should be confirmed");
    });

    // Without paper printed and pieces cut there is nothing to stamp.
    await test("The Estamparia waits for the Impressão and the Corte; the panel links every stage", async () => {
      const etapas = await page.locator(".pedido-ir-producao a").allInnerTexts();
      if (etapas.join("|") !== "Impressão →|Corte →|Estamparia →|Conferência →") throw new Error(`Stages: ${etapas.join("|")}`);
      await Promise.all([ page.waitForURL(`**/pedidos/${pedidoUuid}/etapas/estamparia`), page.locator("a.pedido-ir-estamparia").click() ]);
      await page.locator("tr.etapa-linha .baixa-aguardando", { hasText: "aguardando Impressão" }).waitFor();
      if (await page.locator("[data-controller=baixa]").count()) throw new Error("Nothing can be stamped yet");
    });

    await test("Impressão: a measure far from the paper the files expect is warned; corrected, the line is done", async () => {
      await page.goto(`${BASE_URL}/pedidos/${pedidoUuid}/impressao`);
      const linha = page.locator("tr.impressao-linha .baixa");
      await darBaixa(linha, "98");
      // 10 pieces × 15,24 mm = 0,15 m expected; 98 m is a typo.
      await linha.locator(".baixa-mensagem.baixa-aviso", { hasText: "Esperado ~0,15 m, você informou 98 m" }).waitFor();
      if (!(await linha.locator(".baixa-confirmar").isVisible())) throw new Error("The warning should offer to confirm");
      await linha.locator(".baixa-medida").fill("0,16");
      if (await linha.locator(".baixa-confirmar").isVisible()) throw new Error("A new value asks again");
      await salvoERecarregado(() => linha.locator(".baixa-salvar").click());
      const feita = (await page.locator("tr.impressao-linha .baixa-feita").innerText()).trim();
      if (!feita.startsWith("✓ 0,16 m ·")) throw new Error(`Done line: "${feita}"`);
      if ((await page.locator(".etapa-andamento-texto").innerText()).trim() !== "1 de 1 linha feita") throw new Error("Progress should be 1 of 1");
    });

    await test("A value confirmed outside the band is saved marked", async () => {
      await page.goto(`${BASE_URL}/pedidos/${pedidoUuid}/corte`);
      const pedido = page.locator(".etapa-andamento .baixa");
      await salvoERecarregado(() => darBaixa(pedido, "1,5"));
      // No material on the item: the Corte has no expected, so no warning.
      await page.locator("tr.corte-linha .baixa-feita", { hasText: "✓ 1,50 m" }).waitFor();
    });

    await test("Estamparia opens once printed and cut: the referência's baixa in pieces, with a warning below", async () => {
      await page.goto(`${BASE_URL}/pedidos/${pedidoUuid}/etapas/estamparia`);
      const referencia = page.locator(".impressao-arte-topo .baixa");
      await darBaixa(referencia, "8");
      await referencia.locator(".baixa-aviso", { hasText: "Esperado ~10 peças, você informou 8 peças" }).waitFor();
      await salvoERecarregado(() => referencia.locator(".baixa-confirmar").click());
      await page.locator("tr.etapa-linha .baixa-fora", { hasText: "fora da faixa" }).waitFor();

      await page.locator(".etapas-nav a", { hasText: "Conferência" }).click();
      await page.waitForURL(`**/pedidos/${pedidoUuid}/etapas/conferencia`);
      if ((await page.locator("tr.etapa-linha").getAttribute("data-situacao")) !== "aberta") throw new Error("Conferência should open after the Estamparia");
    });

    // Etapa 2.2 (3/3, decided 07/10/2026): a baixa is undone until the
    // delivery — not one a later stage already used. (The runner accepts
    // the "Desfazer esta baixa?" confirmation itself.)
    await test("Undo: the Corte can't be undone while the Estamparia used it; the Estamparia can, and its line reopens", async () => {
      await page.goto(`${BASE_URL}/pedidos/${pedidoUuid}/corte`);
      await Promise.all([ page.waitForURL(`**/pedidos/${pedidoUuid}/corte`), page.locator("tr.corte-linha .baixa-desfazer").click() ]);
      await page.getByText("Could not undo the baixa: Undo Estamparia's baixa of these lines first").waitFor();

      await page.goto(`${BASE_URL}/pedidos/${pedidoUuid}/etapas/estamparia`);
      await Promise.all([ page.waitForURL(`**/pedidos/${pedidoUuid}/etapas/estamparia`), page.locator("tr.etapa-linha .baixa-desfazer").click() ]);
      await page.getByText("Baixa de Estamparia desfeita").waitFor();
      if ((await page.locator("tr.etapa-linha").getAttribute("data-situacao")) !== "aberta") throw new Error("The line should be open again");
      await page.locator(".historico-baixas summary").click();
      await page.locator(".historico-baixa--desfeita .historico-baixa-desfeita", { hasText: "desfeita por" }).waitFor();
    });

    await test("Marcar como entregue warns about the open stages; delivered anyway, the pedido is read only", async () => {
      await page.goto(`${BASE_URL}/pedidos/${pedidoUuid}/resumo`);
      if ((await page.locator("h2 .badge").innerText()).trim() !== "em produção") throw new Error("The first baixa puts the pedido in production");
      await page.locator(".entrega-botao").click();
      await page.locator(".entrega .baixa-aviso", { hasText: "Ainda faltam: Estamparia 1 linha, Conferência 1 linha." }).waitFor();
      await Promise.all([ page.waitForResponse((r) => r.url().endsWith(`/pedidos/${pedidoUuid}/entregar`)), page.locator(".entrega-confirmar").click() ]);
      await page.locator(".pedido-entregue", { hasText: "Entregue em" }).waitFor();
      if ((await page.locator("h2 .badge").innerText()).trim() !== "entregue") throw new Error("The pedido should be delivered");

      await page.goto(`${BASE_URL}/pedidos/${pedidoUuid}/etapas/estamparia`);
      if (await page.locator("[data-controller=baixa], .baixa-desfazer").count()) throw new Error("A delivered pedido takes no baixas and undoes none");

      await page.goto(`${BASE_URL}/pedidos?status=entregue`);
      await page.locator("tr", { has: page.locator(`a[href="/pedidos/${pedidoUuid}"]`) }).locator(".badge-entregue").waitFor();
    });
  } finally {
    fs.rmSync(pasta, { recursive: true, force: true });
  }
});
