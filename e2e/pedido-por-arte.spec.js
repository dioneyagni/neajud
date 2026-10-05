const path = require("path");
const fs = require("fs");
const os = require("os");
const { uploadFileAndWait } = require("./support/upload");
const { waitForQueuedTask } = require("./support/wait");
const { BASE_URL, runSpec } = require("./support/runner");
const { modeloOficial } = require("./support/catalogo");

// Etapa 1.2 (3/3, parte 1; decided 05/10/2026): an item is an arte, its grade
// by individual size (the molde's stretch), and it can be added from the
// pedido page by molde → referência → arte, not only from the gallery.
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
    await test("Setup: an arte in a molde from 29 to 31", async () => {
      await page.goto(BASE_URL);
      const tenis = await modeloOficial(page, "Tenis");
      await post("/clients", { "client[name]": nomes.cliente, "client[responsible]": "T" });
      const clienteUuid = await buscar(`/clients/search?q=${encodeURIComponent(nomes.cliente)}`, "name", nomes.cliente);
      await post("/moldes", { "molde[sufixo]": nomes.molde, "molde[client_uuid]": clienteUuid, "molde[modelo_uuid]": tenis.id,
        "molde[tamanho_inicial]": "29", "molde[tamanho_final]": "31" });
      const moldeUuid = await buscar(`/moldes/search?q=${encodeURIComponent(nomes.molde)}`, "sufixo", nomes.molde);

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
      if (tamanhos.join("|") !== "29|30|31") throw new Error(`The grade should be the molde's numbers, got ${tamanhos.join("|")}`);
      await modal.locator('.add-to-order-grade-input[data-tamanho-nome="29"]').fill("4");
      await modal.locator('.add-to-order-grade-input[data-tamanho-nome="30"]').fill("6");
      await Promise.all([ page.waitForEvent("load"), modal.locator('button:has-text("Adicionar")').click() ]);

      const item = page.locator(".pedido-item").filter({ hasText: `PEDIDO${U}` });
      await item.waitFor();
      const grade = await item.locator(".grade-qtd-input").evaluateAll((els) => els.map((el) => `${el.dataset.tamanhoNome}=${el.value}`));
      if (grade.join("|") !== "29=4|30=6|31=0") throw new Error(`Unexpected grade on the pedido: ${grade.join("|")}`);
    });
  } finally {
    fs.rmSync(pasta, { recursive: true, force: true });
  }
});
