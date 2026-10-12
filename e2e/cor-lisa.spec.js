// Etapa 2.5b (decided 12/10/2026): the cor lisa, measured. Solid-color files
// made here with ImageMagick — two oranges a hair apart and a blue — are
// uploaded as "Cor lisa": the system names each by its family, numbered per
// family; the second orange points at the first as practically equal; the
// material is set apart from the name; "Cores" shows them in the chart and
// the table; a new version of the blue is measured again and keeps its name.
const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");
const { BASE_URL, runSpec } = require("./support/runner");
const { ensureMaterialExists } = require("./support/materiais");
const { uploadFileAndWait, waitForUploadedProcessed } = require("./support/upload");
const { waitForText } = require("./support/wait");

runSpec("Cor lisa E2E Tests", async ({ page, test }) => {
  const U = Date.now();
  const pasta = fs.mkdtempSync(path.join(os.tmpdir(), "cor-lisa-"));
  const ids = {};
  const nomes = {};

  function solida(nome, cor) {
    const destino = path.join(pasta, `${nome}${U}.tif`);
    execFileSync("convert", ["-size", "60x60", `xc:${cor}`, destino]);
    return destino;
  }

  // The measure runs on the queue after processing: poll the page's name.
  async function nomeDaCor(uuid) {
    for (let i = 0; i < 60; i++) {
      const html = await (await page.request.get(`${BASE_URL}/arquivos/${uuid}`)).text();
      const codigo = html.match(/id="cor-lisa-section" data-codigo="([^"]+)"/)?.[1];
      if (codigo) return codigo;
      await new Promise((r) => setTimeout(r, 1000));
    }
    throw new Error(`${uuid} was never measured`);
  }

  function idDoCartao(nome) {
    return page.locator(".stamp-card").filter({ hasText: `${nome}${U}` }).getAttribute("id").then((id) => id.replace(/^arquivo_/, ""));
  }

  await test("Three solid colors uploaded as Cor lisa are named by the system", async () => {
    await page.goto(`${BASE_URL}/arquivos`);
    await page.selectOption('[data-upload-target="tipo"]', "cor_lisa");
    await uploadFileAndWait(page, [solida("laranjaum", "#EF4123"), solida("laranjadois", "#EF4224"), solida("azulum", "#0071BB")]);
    for (const nome of ["laranjaum", "laranjadois", "azulum"]) {
      ids[nome] = await idDoCartao(nome);
      nomes[nome] = await nomeDaCor(ids[nome]);
    }
    const [l1, l2] = [nomes.laranjaum, nomes.laranjadois].map((n) => Number(n.match(/^Laranja (\d+)$/)?.[1]));
    if (!l1 || !l2 || Math.abs(l1 - l2) !== 1) throw new Error(`Oranges named ${nomes.laranjaum} and ${nomes.laranjadois}`);
    if (!/^Azul \d+$/.test(nomes.azulum)) throw new Error(`Blue named ${nomes.azulum}`);
  });

  await test("The second orange points at the first as practically equal", async () => {
    await page.goto(`${BASE_URL}/arquivos/${ids.laranjadois}`);
    const igual = page.locator(`.cor-parecida--praticamente_igual[data-codigo="${nomes.laranjaum}"]`);
    await igual.waitFor({ timeout: 5000 });
    if (!(await igual.innerText()).includes("praticamente igual")) throw new Error("No 'praticamente igual' notice");
  });

  await test("The material is set apart from the name", async () => {
    await ensureMaterialExists(page, BASE_URL);
    await page.goto(`${BASE_URL}/arquivos/${ids.laranjaum}`);
    const opcao = page.locator("#cor-lisa-material-select option:not([value=''])").first();
    const material = (await opcao.innerText()).trim();
    await page.selectOption("#cor-lisa-material-select", await opcao.getAttribute("value"));
    await waitForText(page, `Material of ${nomes.laranjaum}`);
    if (!(await page.locator(".cor-lisa-material").innerText()).includes(material)) throw new Error("The material isn't shown");
    if ((await page.locator(".cor-lisa-nome").innerText()).trim() !== nomes.laranjaum) throw new Error("The material changed the name");
  });

  await test("Cores shows them in the chart and the table, by family", async () => {
    await page.goto(`${BASE_URL}/cores`);
    for (const nome of Object.values(nomes)) await page.locator(`.cores-tabela tr[data-codigo="${nome}"]`).waitFor({ timeout: 5000 });
    if (!(await page.locator(".cartela-celula:not(.cartela-celula--vazia)").count())) throw new Error("The chart is empty");
    await page.click('.cores-filtro a:text-is("Azul")');
    await page.waitForURL(/familia=Azul/);
    if (await page.locator(`.cores-tabela tr[data-codigo="${nomes.laranjaum}"]`).count()) throw new Error("The Azul filter lists an orange");
  });

  await test("A new version of the blue is measured again and keeps its name", async () => {
    const bytes = Array.from(fs.readFileSync(solida("azuldois", "#005A96")));
    await page.goto(`${BASE_URL}/arquivos/${ids.azulum}`);
    const ok = await page.evaluate(async ({ url, bytes, nome }) => {
      const corpo = new FormData();
      corpo.append("authenticity_token", document.querySelector('meta[name="csrf-token"]')?.content || "");
      corpo.append("original_file", new File([new Uint8Array(bytes)], nome, { type: "image/tiff" }));
      return (await fetch(url, { method: "POST", body: corpo })).ok;
    }, { url: `/arquivos/${ids.azulum}/upload_version`, bytes, nome: `azulum${U}.tif` });
    if (!ok) throw new Error("upload_version failed");
    await waitForUploadedProcessed(page, [ids.azulum], [`azulum${U}`]);
    for (let i = 0; i < 60; i++) {
      const html = await (await page.request.get(`${BASE_URL}/arquivos/${ids.azulum}`)).text();
      if (html.includes("#005A96")) {
        if (!html.includes(`data-codigo="${nomes.azulum}"`)) throw new Error("The new version renamed the color");
        return;
      }
      await new Promise((r) => setTimeout(r, 1000));
    }
    throw new Error("The new version was never measured");
  });

  await test("Cleanup", async () => {
    fs.rmSync(pasta, { recursive: true, force: true });
  });
});
