// Dublagem 2/5 (decided 29/10/2026): the dublagem network, read only, from
// config/dublagens.yml. The team opens it from Grupos; a group the network
// names but nobody registered is a warning, never an error (decision 1), and
// the warning goes away once the group is registered.
const { BASE_URL, runSpec } = require("./support/runner");

runSpec("Rede de dublagens E2E Tests", async ({ page, test }) => {
  const linhaDoEva = '.rede-ligacao[data-par="Oxford–EVA"]';

  async function textoDaLinha() {
    return (await page.locator(linhaDoEva).innerText()).replace(/\s+/g, " ");
  }

  await test("Opens from Grupos, with each ligação's ligantes, situações and before/after", async () => {
    await page.goto(`${BASE_URL}/grupos-de-material`);
    await page.locator("a.rede-link").click();
    await page.locator(".rede-pagina h2").waitFor();
    const lona = page.locator('.rede-ligacao[data-par="Oxford–Lona"]');
    if (!(await lona.innerText()).includes("Filme 35 µm ou mais")) throw new Error("Oxford–Lona doesn't show its filme");
    if ((await lona.locator('[data-situacao="tecido_molha"]').innerText()).trim() !== "Filme PU") throw new Error("Tecido molha doesn't change to Filme PU");
    if ((await lona.locator(".rede-chip--antes").count()) !== 1) throw new Error("Oxford–Lona isn't marked 'dubla antes'");
    if (!(await lona.innerText()).includes("a confirmar")) throw new Error("The guessed fields aren't marked");
  });

  // The test database starts without EVA: the network still loads.
  await test("A group not registered is a warning, gone once it is registered", async () => {
    if (!(await textoDaLinha()).includes("EVA — não cadastrado")) throw new Error("No 'EVA — não cadastrado' warning");
    await page.evaluate(async () => {
      const token = document.querySelector('meta[name="csrf-token"]')?.content || "";
      await fetch("/materiais/create_grupo", { method: "POST", body: new URLSearchParams({ authenticity_token: token, "grupo_material[nome]": "EVA" }) });
    });
    await page.reload();
    await page.locator(linhaDoEva).waitFor();
    if ((await textoDaLinha()).includes("EVA — não cadastrado")) throw new Error("The warning stayed after EVA was registered");
  });

  await test("The table scrolls inside its card on a phone, never the page", async () => {
    await page.setViewportSize({ width: 390, height: 800 });
    const larguras = await page.evaluate(() => [document.documentElement.scrollWidth, window.innerWidth]);
    await page.setViewportSize({ width: 1280, height: 800 });
    if (larguras[0] > larguras[1]) throw new Error(`The page scrolls sideways: ${larguras.join(" > ")}`);
  });
});
