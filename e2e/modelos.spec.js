const { BASE_URL, runSpec } = require("./support/runner")

// Etapa 1.1 (3/5): the Modelos page is the official Neajud list (products,
// categories with abbreviation and grade), loaded from
// config/catalogo_oficial.yml — read only for the company.
runSpec("Modelos E2E Tests", async ({ page, test }) => {

  await test("nav link", async () => {
    await page.goto(BASE_URL + "/")
    const hrefs = await page.evaluate(() =>
      Array.from(document.querySelectorAll("nav a")).map(a => a.href)
    )
    if (!hrefs.some(h => h.includes("/modelos"))) throw Error("missing nav link")
  })

  await test("index lists the official catalog by produto, with abbreviations and grades", async () => {
    await page.goto(`${BASE_URL}/modelos`)
    await page.waitForSelector("h2")
    const calcado = page.locator('.catalogo-produto[data-produto="Calçado"]')
    const texto = await calcado.textContent()
    for (const esperado of ["Grade 18–46", "Tenis", "TNS", "Jogging", "JGG", "Bota", "BT", "Calce Fácil", "CLCF", "Chuteira", "CHT", "Chinelo", "CHN", "Slide", "SLD"]) {
      if (!texto.includes(esperado)) throw Error(`Calçado section is missing "${esperado}": ${texto.replace(/\s+/g, " ").slice(0, 300)}`)
    }
    const camisa = await page.locator('.catalogo-produto[data-produto="Camisa"]').textContent()
    if (!camisa.includes("Grade PP–XG") || !camisa.includes("CMS")) throw Error(`Camisa section wrong: ${camisa.replace(/\s+/g, " ")}`)
    const banner = await page.locator('.catalogo-produto[data-produto="Banner"]').textContent()
    if (!banner.includes("No grade") || !banner.includes("BNN")) throw Error(`Banner section wrong: ${banner.replace(/\s+/g, " ")}`)
  })

  // The company can't register, edit or delete a modelo: it asks Neajud.
  await test("index offers no create, edit or delete", async () => {
    await page.goto(`${BASE_URL}/modelos`)
    await page.waitForSelector("h2")
    const acoes = await page.locator('a[href="/modelos/new"], a[href$="/edit"][href^="/modelos"], main button.btn-danger').count()
    if (acoes !== 0) throw Error(`Expected no create/edit/delete controls, found ${acoes}`)
    const resposta = await page.request.get(`${BASE_URL}/modelos/new`)
    if (resposta.status() !== 404) throw Error(`/modelos/new should be gone, got ${resposta.status()}`)
  })

  await test("show page of an official modelo", async () => {
    await page.goto(`${BASE_URL}/modelos`)
    await page.locator('.catalogo-produto[data-produto="Calçado"] a', { hasText: "Jogging" }).click()
    await page.waitForURL(/\/modelos\/[0-9a-f-]{36}$/)
    const body = await page.textContent("body")
    if (!body.includes("Calçado") || !body.includes("JGG")) throw Error(`Show page lacks produto/abbreviation: ${body.replace(/\s+/g, " ").slice(0, 300)}`)
  })
})
