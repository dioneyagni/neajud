// Dublagem 2/5 (decided 29/10/2026): the dublagem network, read only; from
// the database since rede editável 1/2 (09/11/2026), its groups registered.
// The team opens it from Grupos.
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

  // Rede editável 1/2 (Q1a, Q8a): the network is in the database, its
  // groups by registration — bin/e2e imports the initial one, which created
  // EVA with its roles. So no ligação says "não cadastrado" any more.
  await test("Every group of the network is registered: EVA is in Grupos, no 'não cadastrado'", async () => {
    if ((await textoDaLinha()).includes("não cadastrado")) throw new Error("Oxford–EVA still warns a group isn't registered");
    await page.goto(`${BASE_URL}/grupos-de-material`);
    if (!(await page.locator("body").innerText()).includes("EVA")) throw new Error("The import didn't register EVA");
    await page.goBack();
  });

  await test("The table scrolls inside its card on a phone, never the page", async () => {
    await page.setViewportSize({ width: 390, height: 800 });
    const larguras = await page.evaluate(() => [document.documentElement.scrollWidth, window.innerWidth]);
    await page.setViewportSize({ width: 1280, height: 800 });
    if (larguras[0] > larguras[1]) throw new Error(`The page scrolls sideways: ${larguras.join(" > ")}`);
  });
});
