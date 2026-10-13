// Etapa 2.5a (decided 12/10/2026): the kind of work. The team uploads two
// etiquetas as DTF — each gets the next number; one becomes an estampa
// corrida (CR-n) and enters the catálogo; the other stays its client's. A
// cliente final of another client sees the one in the catálogo — without
// whose it is, nor any control to change it — and never the other.
const fs = require("fs");
const os = require("os");
const path = require("path");
const { BASE_URL, runSpec } = require("./support/runner");
const { testImagePath, ensureTestImage } = require("./support/fixtures");
const { submitUploadAndWait, uploadFileAndWait } = require("./support/upload");
const { waitForText } = require("./support/wait");

runSpec("Tipo da arte E2E Tests", async ({ page, test }) => {
  const U = Date.now();
  const nomes = { dono: `Dono Etiqueta ${U}`, leitor: `Leitor Catalogo ${U}`, um: `etiquetaum${U}`, dois: `etiquetadois${U}` };
  const rui = { email: `rui${U}@neajud.test`, provisoria: "provisoria-rui-1", senha: "senha-rui-e2e-1" };
  const ids = {};
  const pasta = fs.mkdtempSync(path.join(os.tmpdir(), "tipo-da-arte-"));

  function copia(nome) {
    const destino = path.join(pasta, `${nome}.tif`);
    fs.copyFileSync(testImagePath, destino);
    return destino;
  }

  async function criarCliente(nome) {
    const ok = await page.evaluate(async (nome) => {
      const token = document.querySelector('meta[name="csrf-token"]')?.content || "";
      return (await fetch("/clients", { method: "POST", body: new URLSearchParams({ authenticity_token: token, "client[name]": nome, "client[responsible]": "T" }) })).ok;
    }, nome);
    if (!ok) throw new Error(`Couldn't create ${nome}`);
    return page.evaluate(async (nome) => (await (await fetch(`/clients/search?q=${encodeURIComponent(nome)}`)).json()).find((c) => c.name === nome)?.id, nome);
  }

  function cartao(nome) {
    return page.locator(".stamp-card").filter({ hasText: nome });
  }

  await test("Setup: the etiqueta's client, and another client with an access", async () => {
    ensureTestImage();
    await page.goto(BASE_URL);
    ids.dono = await criarCliente(nomes.dono);
    ids.leitor = await criarCliente(nomes.leitor);
    await page.goto(`${BASE_URL}/clients/${ids.leitor}`);
    const secao = page.locator("#acesso-ao-sistema");
    await secao.locator("#acesso_nome").fill(`Rui ${U}`);
    await secao.locator("#acesso_email").fill(rui.email);
    await secao.locator("#acesso_senha").fill(rui.provisoria);
    await secao.locator('input[type="submit"][value="Add access"]').click();
    await page.locator(`#acesso-ao-sistema tr.usuario-linha[data-email="${rui.email}"]`).waitFor({ timeout: 10000 });
  });

  await test("The team uploads two etiquetas as DTF: each takes the next number", async () => {
    await page.goto(`${BASE_URL}/arquivos`);
    await page.selectOption('[data-upload-target="tipo"]', "dtf");
    await uploadFileAndWait(page, [copia(nomes.um), copia(nomes.dois)]);
    const numeros = [];
    for (const nome of [nomes.um, nomes.dois]) {
      const codigo = (await cartao(nome).locator(".stamp-card-tipo").innerText()).trim();
      if (!/^DTF-\d+$/.test(codigo)) throw new Error(`${nome} shows ${codigo}`);
      numeros.push(Number(codigo.split("-")[1]));
      ids[nome] = (await cartao(nome).getAttribute("id")).replace(/^arquivo_/, "");
    }
    if (Math.abs(numeros[0] - numeros[1]) !== 1) throw new Error(`Numbers aren't the next ones: ${numeros}`);
    // Pedidos are calçado's until DTF gets its own (Etapa 2.6).
    if (await cartao(nomes.um).locator(".btn-add-to-order").count()) throw new Error("A DTF card offers Pedido");
  });

  // The conference's own kind per group: two sizes of one etiqueta, one arte, one number.
  await test("In the conference a group takes its own kind: two sizes, one DTF number", async () => {
    await page.goto(`${BASE_URL}/arquivos`);
    await page.setInputFiles('input[type="file"]', [copia(`55-ARCO${U}-23_24`), copia(`55-ARCO${U}-25_26`)]);
    const grupo = page.locator(".conferencia-grupo");
    await grupo.first().waitFor({ timeout: 10000 });
    if ((await grupo.count()) !== 1) throw new Error("Expected one group");
    if ((await grupo.locator("select.conferencia-parte").count()) !== 2) throw new Error("A calçado group has no part per file");
    // Etapa 2.5c: a DTF has no part, side or piloto (each file is the editable one), only its size.
    await grupo.locator("select.conferencia-tipo").selectOption("dtf");
    await grupo.locator("select.conferencia-parte").first().waitFor({ state: "detached", timeout: 5000 });
    if (await grupo.locator(".conferencia-lado, .conferencia-piloto").count()) throw new Error("A DTF group still has side or piloto");
    if ((await grupo.locator(".conferencia-tamanho").count()) !== 2) throw new Error("A DTF group lost its sizes");
    // A corrida, sold by the meter, has no size either.
    await grupo.locator("select.conferencia-tipo").selectOption("corrida");
    await grupo.locator(".conferencia-tamanho").first().waitFor({ state: "detached", timeout: 5000 });
    await grupo.locator("select.conferencia-tipo").selectOption("dtf");
    await grupo.locator(".conferencia-tamanho").nth(1).waitFor({ timeout: 5000 });
    await submitUploadAndWait(page, 2);
    const codigo = await cartao(`55-ARCO${U}`).locator(".stamp-card-tipo").innerText({ timeout: 10000 });
    if (!/^DTF-\d+$/.test(codigo.trim())) throw new Error(`The group shows ${codigo}`);
    if (!(await cartao(`55-ARCO${U}`).innerText()).includes("2 files")) throw new Error("The two sizes aren't one arte");
  });

  // Etapa 2.5c (decided 13/10/2026): a DTF's sizes came numbered by hand one
  // by one; in a DTF upload that leading number doesn't separate them.
  await test("A DTF upload joins sizes numbered apart into one etiqueta", async () => {
    await page.goto(`${BASE_URL}/arquivos`);
    await page.setInputFiles('input[type="file"]', [copia(`872-PAIS${U} - P - 1,6 X 1,7`), copia(`873-PAIS${U} - M - 2 X 2`)]);
    // As calçado, the leading number separates: two artes of one file, nothing to confer.
    await page.locator(".upload-file").nth(1).waitFor({ timeout: 10000 });
    if (await page.locator(".conferencia-grupo").count()) throw new Error("Calçado grouped files of different references");
    await page.selectOption('[data-upload-target="tipo"]', "dtf");
    const grupo = page.locator(".conferencia-grupo");
    await grupo.first().waitFor({ timeout: 10000 });
    if ((await grupo.count()) !== 1) throw new Error("The DTF's sizes aren't one group");
    const titulo = (await grupo.locator(".conferencia-grupo-titulo").innerText()).trim();
    if (titulo !== `PAIS${U}`) throw new Error(`The group is titled ${titulo}`);
    await submitUploadAndWait(page, 2);
    const resumo = await cartao(`PAIS${U}`).locator(".stamp-card-arte").innerText({ timeout: 10000 });
    if (resumo.trim() !== "2 files · M, P") throw new Error(`The etiqueta sums up as ${resumo}`);
    await page.selectOption('[data-upload-target="tipo"]', "calcado");
  });

  // Etapa 2.5c: no part, consumption or piloto on a DTF's page — only its sizes.
  await test("The DTF's page lists its sizes, without part, paper consumption or piloto", async () => {
    await cartao(`55-ARCO${U}`).locator("a").first().click();
    const lista = page.locator("#arte-arquivos");
    await lista.waitFor({ timeout: 10000 });
    if ((await lista.locator(".arte-arquivo-tamanho").count()) !== 2) throw new Error("The DTF's sizes aren't listed");
    if (await lista.locator("h4, .arte-arquivo-consumo, .arte-tornar-piloto, .arte-lado, select[name=peca_uuid]").count()) {
      throw new Error("A DTF's page shows part, consumption or piloto");
    }
  });

  await test("Each gets its client; one becomes an estampa corrida and enters the catálogo", async () => {
    for (const nome of [nomes.um, nomes.dois]) {
      const ok = await page.evaluate(async ({ uuid, cliente }) => {
        const token = document.querySelector('meta[name="csrf-token"]')?.content || "";
        return (await fetch(`/arquivos/${uuid}/update_client`, { method: "POST", body: new URLSearchParams({ authenticity_token: token, _method: "patch", client_uuid: cliente }) })).ok;
      }, { uuid: ids[nome], cliente: ids.dono });
      if (!ok) throw new Error(`Couldn't give ${nome} its client`);
    }
    await page.goto(`${BASE_URL}/arquivos/${ids[nomes.um]}`);
    await page.selectOption("#tipo-da-arte-select", "corrida");
    await page.click('.tipo-da-arte-form button[type="submit"]');
    await waitForText(page, "is now Estampa corrida (CR-");
    await page.locator("#tipo-da-arte-no-catalogo").check();
    await waitForText(page, "is in the catálogo: every client sees it.");
    if ((await page.locator("#tipo-da-arte-section").getAttribute("data-tipo")) !== "corrida") throw new Error("The kind didn't change");
    // Sold by the meter: a corrida's file has no size.
    if (await page.locator("#arte-arquivos .arte-arquivo-tamanho, #arte-arquivos input[name=tamanho_rotulo]").count()) throw new Error("A corrida shows a size");
  });

  await test("Another client's person sees the catálogo's work, without its owner or controls, and never the other", async () => {
    await page.goto(`${BASE_URL}/pedidos`);
    await page.click('.header-user button:has-text("Sign out")');
    await page.waitForURL("**/session/new");
    await page.fill('input[name="email_address"]', rui.email);
    await page.fill('input[name="password"]', rui.provisoria);
    await page.click('input[type="submit"][value="Sign in"]');
    await page.waitForURL("**/senha/edit");
    await page.fill('input[name="nova_senha"]', rui.senha);
    await page.click('input[type="submit"][value="Change password"]');
    await page.waitForURL(/\/pedidos$/);
    await page.goto(`${BASE_URL}/arquivos?tipo=corrida`);
    await cartao(nomes.um).waitFor({ timeout: 5000 });
    // Outside the catálogo an etiqueta is its client's only.
    await page.goto(`${BASE_URL}/arquivos?tipo=dtf`);
    if (await cartao(nomes.dois).count()) throw new Error("He sees the other client's etiqueta");
    await page.goto(`${BASE_URL}/arquivos/${ids[nomes.um]}`);
    const pagina = await page.locator(".stamp-detail-info").innerText();
    if (pagina.includes(nomes.dono)) throw new Error("He sees whose the work is");
    if (await page.locator("#tipo-da-arte-select, #tipo-da-arte-no-catalogo, .arte-acrescentar").count()) throw new Error("He gets controls to change it");
  });

  await test("Cleanup", async () => {
    fs.rmSync(pasta, { recursive: true, force: true });
  });
});
