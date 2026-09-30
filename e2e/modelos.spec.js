const { BASE_URL, runSpec } = require("./support/runner")

const createModelo = async (page, nome) => {
  await page.goto(`${BASE_URL}/modelos/new`)
  await page.waitForSelector("h2", { timeout: 5000 })
  await page.fill("input[name='modelo[nome]']", nome)
  await page.click("input[type='submit']")
  await page.waitForTimeout(1500)
}

runSpec("Modelos E2E Tests", async ({ page, test }) => {

  await test("nav link", async () => {
    await page.goto(BASE_URL + "/")
    const hrefs = await page.evaluate(() =>
      Array.from(document.querySelectorAll("nav a")).map(a => a.href)
    )
    if (!hrefs.some(h => h.includes("/modelos"))) throw Error("missing nav link")
  })

  await test("index heading", async () => {
    await page.goto(`${BASE_URL}/modelos`)
    await page.waitForSelector("h2")
    const b = await page.textContent("body")
    if (!b.includes("Modelos")) throw Error("heading not found")
  })

  await test("create modelo", async () => {
    const nome = "E2E Test " + Date.now()
    await createModelo(page, nome)
    const b = await page.textContent("body")
    if (!b.includes(nome)) throw Error("name not found after creation")
  })

  await test("new page Componentes section", async () => {
    await page.goto(`${BASE_URL}/modelos/new`)
    await page.waitForSelector("h2")
    const b = await page.textContent("body")
    if (!b.includes("Componentes")) throw Error("no Componentes heading")
    const input = await page.$(".componentes-input")
    if (!input) throw Error("no componentes input")
  })

  await test("add componente via combobox", async () => {
    // Ensure a peca exists
    await page.goto(`${BASE_URL}/pecas/new`)
    await page.waitForSelector("h2", { timeout: 5000 })
    await page.fill("input[name='peca[nome]']", "ComponenteTest")
    await page.click("input[type='submit']")
    await page.waitForTimeout(1000)

    // Go to new modelo page
    await page.goto(`${BASE_URL}/modelos/new`)
    await page.waitForSelector("h2")

    // Type in combobox
    const input = await page.$(".componentes-input")
    await input.fill("Componente")
    await page.waitForTimeout(600)

    // Wait for results dropdown
    try {
      await page.waitForSelector(".combobox-results--open", { timeout: 3000 })
    } catch (_) {}

    // Click the option
    const opt = await page.$(".combobox-option[data-nome]")
    if (opt) {
      await opt.click()
      await page.waitForTimeout(300)
    }

    // Check item was added to list
    const items = await page.$$(".componentes-lista li")
    if (items.length === 0) throw Error("no componentes were added to the list")

    // Submit form
    await page.fill("input[name='modelo[nome]']", "Modelo Combo " + Date.now())
    await page.click("input[type='submit']")
    await page.waitForTimeout(1500)

    const b = await page.textContent("body")
    if (!b.includes("Modelo registered")) throw Error("modelo was not created")
  })

  await test("edit modelo", async () => {
    await createModelo(page, "E2E Edit " + Date.now())
    const url = page.url()
    await page.goto(url + "/edit")
    await page.waitForSelector("h2")
    const inp = await page.$("input[name='modelo[nome]']")
    const val = await inp.inputValue()
    await inp.fill(val + " Edited")
    await page.click("input[type='submit']")
    await page.waitForTimeout(1500)
    const b = await page.textContent("body")
    if (!b.includes(val + " Edited")) throw Error("name not updated")
  })

})
