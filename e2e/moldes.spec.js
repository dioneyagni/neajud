const { chromium } = require("playwright")
const BASE_URL = "http://127.0.0.1:3000"

let pass = 0, fail = 0
const t = async (name, fn) => {
  try { await fn(); console.log("PASS", name); pass++ }
  catch (e) { console.log("FAIL", name, "-", e.message.split("\n")[0]); fail++ }
}

const createMolde = async (page, nome) => {
  await page.goto(`${BASE_URL}/moldes/new`)
  await page.waitForSelector("h2", { timeout: 5000 })
  await page.fill("input[name='molde[nome]']", nome)
  await page.click("input[type='submit']")
  await page.waitForTimeout(1500)
}

;(async () => {
  const browser = await chromium.launch()
  const page = await browser.newPage()

  await t("nav link", async () => {
    await page.goto(BASE_URL + "/")
    const hrefs = await page.evaluate(() =>
      Array.from(document.querySelectorAll("nav a")).map(a => a.href)
    )
    if (!hrefs.some(h => h.includes("/moldes"))) throw Error("missing nav link")
  })

  await t("index heading", async () => {
    await page.goto(`${BASE_URL}/moldes`)
    await page.waitForSelector("h2")
    const b = await page.textContent("body")
    if (!b.includes("Moldes")) throw Error("heading not found")
  })

  await t("create molde", async () => {
    const nome = "E2E Test " + Date.now()
    await createMolde(page, nome)
    const b = await page.textContent("body")
    if (!b.includes(nome)) throw Error("name not found after creation")
  })

  await t("new page Componentes section", async () => {
    await page.goto(`${BASE_URL}/moldes/new`)
    await page.waitForSelector("h2")
    const b = await page.textContent("body")
    if (!b.includes("Componentes")) throw Error("no Componentes heading")
    const input = await page.$(".componentes-input")
    if (!input) throw Error("no componentes input")
  })

  await t("add componente via combobox", async () => {
    // Ensure a peca exists
    await page.goto(`${BASE_URL}/pecas/new`)
    await page.waitForSelector("h2", { timeout: 5000 })
    await page.fill("input[name='peca[nome]']", "ComponenteTest")
    await page.click("input[type='submit']")
    await page.waitForTimeout(1000)

    // Go to new molde page
    await page.goto(`${BASE_URL}/moldes/new`)
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
    await page.fill("input[name='molde[nome]']", "Molde Combo " + Date.now())
    await page.click("input[type='submit']")
    await page.waitForTimeout(1500)

    const b = await page.textContent("body")
    if (!b.includes("Molde registered")) throw Error("molde was not created")
  })

  await t("edit molde", async () => {
    await createMolde(page, "E2E Edit " + Date.now())
    const url = page.url()
    await page.goto(url + "/edit")
    await page.waitForSelector("h2")
    const inp = await page.$("input[name='molde[nome]']")
    const val = await inp.inputValue()
    await inp.fill(val + " Edited")
    await page.click("input[type='submit']")
    await page.waitForTimeout(1500)
    const b = await page.textContent("body")
    if (!b.includes(val + " Edited")) throw Error("name not updated")
  })

  console.log(`\nResults: ${pass} passed, ${fail} failed, ${pass + fail} total`)
  await browser.close()
  process.exit(fail > 0 ? 1 : 0)
})()
