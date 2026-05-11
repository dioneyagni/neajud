const { chromium } = require("playwright");
const path = require("path");

const BASE_URL = "http://localhost:3000";

async function run() {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();

  let passed = 0;
  let failed = 0;

  async function test(name, fn) {
    try {
      await fn();
      console.log(`  PASS  ${name}`);
      passed++;
    } catch (err) {
      console.log(`  FAIL  ${name}`);
      console.error(`        ${err.message}`);
      failed++;
    }
  }

  console.log("\nE2E Tests\n");

  await test("Homepage loads and shows title", async () => {
    await page.goto(BASE_URL);
    const title = await page.title();
    if (!title) throw new Error("No page title found");
  });

  await test("Homepage has upload form", async () => {
    await page.goto(BASE_URL);
    const form = await page.$("form");
    if (!form) throw new Error("Upload form not found");
  });

  await test("Homepage shows gallery section", async () => {
    await page.goto(BASE_URL);
    const content = await page.textContent("body");
    if (!content.includes("Stamp Tracker")) throw new Error("Stamp Tracker heading not found");
    if (!content.includes("Gallery")) throw new Error("Gallery section not found");
  });

  await test("Upload form has file input", async () => {
    await page.goto(BASE_URL);
    const fileInput = await page.$('input[type="file"]');
    if (!fileInput) throw new Error("File input not found");
  });

  await test("Creating stamp via form redirects to gallery", async () => {
    await page.goto(BASE_URL);
    await page.fill("#stamp_filename", "e2e-test");
    await page.fill("#stamp_extension", "tif");
    await page.fill("#stamp_mime_type", "image/tiff");
    await page.click('input[type="submit"]');

    await page.waitForURL("**/stamps");
    const body = await page.textContent("body");
    if (!body.includes("uploaded")) throw new Error("Success notice not shown");
  });

  await test("Stamped show page shows details", async () => {
    await page.goto(BASE_URL);
    const firstStampLink = await page.$(".stamp-card a");
    if (!firstStampLink) throw new Error("No stamp cards found");

    const href = await firstStampLink.getAttribute("href");
    if (!href) throw new Error("Stamp link has no href");

    await page.goto(`${BASE_URL}${href}`);
    const body = await page.textContent("body");
    if (!body.includes("Stamp:")) throw new Error("Stamp detail heading not found");
    if (!body.includes("Details")) throw new Error("Details section not found");
    if (!body.includes("Preview")) throw new Error("Preview section not found");
  });

  const summary = `\nResults: ${passed} passed, ${failed} failed, ${passed + failed} total\n`;
  console.log(summary);

  await browser.close();
  process.exit(failed > 0 ? 1 : 0);
}

run().catch((err) => {
  console.error("Fatal:", err);
  process.exit(1);
});