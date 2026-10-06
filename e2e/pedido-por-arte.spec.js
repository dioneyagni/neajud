const path = require("path");
const fs = require("fs");
const os = require("os");
const { uploadFileAndWait } = require("./support/upload");
const { waitForQueuedTask } = require("./support/wait");
const { BASE_URL, runSpec } = require("./support/runner");
const { modeloOficial } = require("./support/catalogo");

// Etapa 1.2 (3/3, parte 1; decided 05/10/2026): an item is an arte, its grade
// by individual size — the numbers its molde's organized DXF serve, "+ before
// / after" from the product's grade — and it can be added from the pedido
// page by molde → referência → arte, not only from the gallery.
runSpec("Pedido: items are artes, by individual size", async ({ page, test }) => {
  const U = `${Date.now()}`.slice(-6);
  const nomes = { cliente: `Pedido Arte ${U}`, molde: `PA${U}`, arquivo: `20-PEDIDO${U}-29_30.tif` };
  const pasta = fs.mkdtempSync(path.join(os.tmpdir(), "neajud-pedido-"));
  let pedidoUuid;

  async function post(url, campos) {
    return page.evaluate(async ({ url, campos }) => {
      const token = document.querySelector('meta[name="csrf-token"]')?.content || "";
      const r = await fetch(url, { method: "POST", body: new URLSearchParams({ authenticity_token: token, ...campos }) });
      return { ok: r.ok, url: r.url };
    }, { url, campos });
  }

  async function buscar(url, chave, valor) {
    return page.evaluate(async ({ url, chave, valor }) => (await (await fetch(url)).json()).find((r) => r[chave] === valor)?.id, { url, chave, valor });
  }

  try {
    await test("Setup: an arte in a molde whose organized DXF is Par 29-30", async () => {
      await page.goto(BASE_URL);
      const tenis = await modeloOficial(page, "Tenis");
      await post("/clients", { "client[name]": nomes.cliente, "client[responsible]": "T" });
      const clienteUuid = await buscar(`/clients/search?q=${encodeURIComponent(nomes.cliente)}`, "name", nomes.cliente);
      await post("/moldes", { "molde[sufixo]": nomes.molde, "molde[client_uuid]": clienteUuid, "molde[modelo_uuid]": tenis.id });
      const moldeUuid = await buscar(`/moldes/search?q=${encodeURIComponent(nomes.molde)}`, "sufixo", nomes.molde);

      // The DXF the grade comes from: organized as Par, one size 29-30.
      const dxf = path.join(pasta, `PA${U}.dxf`);
      fs.copyFileSync(path.join(__dirname, "..", "spec", "fixtures", "files", "29-30.dxf"), dxf);
      await uploadFileAndWait(page, dxf);
      const corteUuid = (await page.locator(".stamp-card").filter({ hasText: `PA${U}` }).first().locator("a").first().getAttribute("href")).split("/").pop();
      const organizado = await post(`/arquivos/${corteUuid}/organize`, { _method: "patch", modelo_uuid: tenis.id, tipo_grade: "par",
        "tamanhos[0][tamanhos]": "30", "tamanhos[0][width_mm]": "150", "tamanhos[0][height_mm]": "250", "tamanhos[0][area_mm2]": "8000" });
      const ligado = await post(`/arquivos/${corteUuid}/add_molde`, { molde_uuid: moldeUuid });
      if (!organizado.ok || !ligado.ok) throw new Error(`organize ok=${organizado.ok}, add_molde ok=${ligado.ok}`);
      await waitForQueuedTask(page, `/arquivos/${corteUuid}/preparacao_tamanhos.json`);

      const caminho = path.join(pasta, nomes.arquivo);
      fs.copyFileSync(path.join(__dirname, "..", "spec", "fixtures", "files", "02-no_spot.tif"), caminho);
      await uploadFileAndWait(page, caminho);
      const arteUuid = (await page.locator(".stamp-card").filter({ hasText: `PEDIDO${U}` }).first().locator("a").first().getAttribute("href")).split("/").pop();
      const ok = await page.evaluate(async ({ arteUuid, moldeUuid }) => {
        const token = document.querySelector('meta[name="csrf-token"]')?.content || "";
        const r = await fetch(`/arquivos/${arteUuid}/update_molde`, { method: "POST", body: new URLSearchParams({ authenticity_token: token, _method: "patch", molde_uuid: moldeUuid }) });
        return r.ok;
      }, { arteUuid, moldeUuid });
      if (!ok) throw new Error("Could not give the arte its molde");
      await waitForQueuedTask(page, `/arquivos/${arteUuid}/busca_tamanho.json`);
      const criado = await post("/pedidos", {});
      pedidoUuid = criado.url.split("/").slice(-2, -1)[0];
    });

    await test("On the pedido page: molde → referência → the arte, added with its grade by number", async () => {
      await page.goto(`${BASE_URL}/pedidos/${pedidoUuid}/resumo`);
      const moldes = page.locator('select[data-pedido-adicionar-target="molde"]');
      await moldes.selectOption(await moldes.locator("option", { hasText: nomes.molde }).getAttribute("value"));
      const referencias = page.locator('select[data-pedido-adicionar-target="referencia"]');
      await referencias.locator("option", { hasText: "20" }).waitFor({ state: "attached" });
      await referencias.selectOption({ label: "20" });
      const card = page.locator(".pedido-adicionar-arte").filter({ hasText: `PEDIDO${U}` });
      await card.waitFor();
      await card.locator("button").click();

      const modal = page.locator(".add-to-order-dialog");
      await modal.waitFor();
      const tamanhos = await modal.locator(".add-to-order-grade-input").evaluateAll((els) => els.map((el) => el.dataset.tamanhoNome));
      if (tamanhos.join("|") !== "29|30") throw new Error(`The grade should be the DXF's numbers, got ${tamanhos.join("|")}`);
      await modal.locator('.add-to-order-grade-input[data-tamanho-nome="29"]').fill("4");
      await modal.locator('.add-to-order-grade-input[data-tamanho-nome="30"]').fill("6");
      // "+ 28" / "+ 31": the product's next numbers outside the DXF's;
      // adding one keeps what was typed.
      if ((await modal.locator(".grade-numeros-mais").allInnerTexts()).join("|") !== "+ 28|+ 31") throw new Error("Expected + 28 and + 31");
      await modal.locator('.grade-numeros-mais:has-text("+ 31")').click();
      await modal.locator('.add-to-order-grade-input[data-tamanho-nome="31"]').fill("1");
      if ((await modal.locator('.add-to-order-grade-input[data-tamanho-nome="29"]').inputValue()) !== "4") throw new Error("Adding a number lost what was typed");
      await Promise.all([ page.waitForEvent("load"), modal.locator('button:has-text("Adicionar")').click() ]);

      const item = page.locator(".pedido-item").filter({ hasText: `PEDIDO${U}` });
      await item.waitFor();
      // Every number of the product's grade is a column (hidden ones too, Etapa 1.2, 3/3 parte 3a).
      const grade = await item.locator(".grade-qtd-input").evaluateAll((els) => els.filter((el) => el.value !== "0").map((el) => `${el.dataset.tamanhoNome}=${el.value}`));
      if (grade.join("|") !== "29=4|30=6|31=1") throw new Error(`Unexpected grade on the pedido: ${grade.join("|")}`);
    });
    // Decided 05/10/2026: number over quantity on wide screens, side by side on
    // narrow ones — the matrix keeps it (Etapa 1.2, 3/3 parte 3a).
    await test("The grade is a responsive table: number over quantity, side by side on a phone", async () => {
      const item = page.locator(".pedido-item").filter({ hasText: `PEDIDO${U}` });
      const posicoes = async () => {
        const r = await item.locator('.pedido-matriz-numero[data-numero="29"]').boundingBox();
        const i = await item.locator('.pedido-matriz-qtd[data-numero="29"]').boundingBox();
        return { embaixo: i.y >= r.y + r.height - 1, aoLado: i.x >= r.x + r.width - 1 };
      };
      if (!(await posicoes()).embaixo) throw new Error("On a wide screen the quantity should be under the number");
      await page.setViewportSize({ width: 390, height: 800 });
      try {
        if (!(await posicoes()).aoLado) throw new Error("On a phone the quantity should be beside the number");
      } finally {
        await page.setViewportSize({ width: 1280, height: 800 });
      }
    });

    // Etapa 1.2 (3/3, parte 3a): the matrix shows the DXF's numbers (29, 30)
    // and the ordered 31; "+ 28" shows the next column of the product's grade.
    // Saving refreshes the page: the new number is resolved (no DXF serves
    // 28) and the side panel recounts.
    await test("'+ 28' shows a hidden column; saving a quantity there resolves it and updates the panel", async () => {
      const item = page.locator(".pedido-item").filter({ hasText: `PEDIDO${U}` });
      const antes = item.locator('[data-grade-matriz-target="antes"]');
      if ((await antes.innerText()).trim() !== "+ 28") throw new Error(`Expected + 28, got ${await antes.innerText()}`);
      if (await item.locator('.pedido-matriz-numero[data-numero="28"]').isVisible()) throw new Error("28 should start hidden");
      await antes.click();
      await item.locator('.pedido-matriz-qtd[data-numero="28"] input').fill("2");
      if ((await antes.innerText()).trim() !== "+ 27") throw new Error("The button should move on to + 27");
      if ((await page.locator('[data-resumo="pares"]').innerText()).trim() !== "11") throw new Error("Pares should start at 11");

      const salvo = page.waitForResponse((r) => new URL(r.url()).pathname.endsWith("/atualizar_item") && r.request().method() === "PATCH");
      const recarregado = page.waitForResponse((r) => r.request().method() === "GET" && new URL(r.url()).pathname === `/pedidos/${pedidoUuid}/resumo`);
      await item.locator(".grade-save-btn").click();
      if (!(await (await salvo).json()).ok) throw new Error("atualizar_item failed");
      await recarregado;
      await page.locator('[data-resumo="pares"]', { hasText: "13" }).waitFor();
      const celula = item.locator('.pedido-parte-numero[data-numero="28"]').first();
      if ((await celula.getAttribute("data-estado")) !== "sem_corte" || !(await celula.isVisible())) throw new Error("28 should show, without corte");
      await page.locator(".pedido-painel .pedido-pendencia--sem_corte", { hasText: "28×2" }).waitFor();
    });
  } finally {
    fs.rmSync(pasta, { recursive: true, force: true });
  }
});
