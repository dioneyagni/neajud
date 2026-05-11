const { chromium } = require("playwright");
const path = require("path");
const fs = require("fs");

const BASE_URL = "http://localhost:3000";
const HEADED = process.argv.includes("--headed") || process.argv.includes("-h");

async function run() {
  const browser = await chromium.launch({ headless: !HEADED, slowMo: HEADED ? 300 : 0 });
  const context = await browser.newContext();
  const page = await context.newPage();

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

  page.on("dialog", async (dialog) => {
    await dialog.accept();
  });

  console.log("\nNeajud E2E Tests\n");

  await test("Homepage loads and shows title", async () => {
    await page.goto(BASE_URL);
    const title = await page.title();
    if (!title) throw new Error("No page title found");
  });

  await test("Homepage has upload form and gallery section", async () => {
    await page.goto(BASE_URL);
    const form = await page.$("form");
    if (!form) throw new Error("Upload form not found");
    const body = await page.textContent("body");
    if (!body.includes("Stamp Tracker")) throw new Error("Stamp Tracker heading not found");
    if (!body.includes("Gallery")) throw new Error("Gallery section not found");
  });

  const testImagePath = path.join(__dirname, "test-image.tif");
  if (!fs.existsSync(testImagePath)) {
    const { execSync } = require("child_process");
    execSync(`convert -size 100x100 xc:red -compress none 'TIFF:${testImagePath}'`);
  }

  await test("Upload a file creates a stamp visible in gallery", async () => {
    await page.goto(BASE_URL);
    const fileInput = await page.$('input[type="file"]');
    if (!fileInput) throw new Error("File input not found");

    await fileInput.setInputFiles(testImagePath);
    await page.fill("#stamp_filename", "e2e-test-image");
    await page.fill("#stamp_extension", "tif");
    await page.fill("#stamp_mime_type", "image/tiff");
    await page.click('input[type="submit"]');

    await page.waitForURL("**/stamps");
    await page.waitForTimeout(500);

    const body = await page.textContent("body");
    if (!body.includes("uploaded")) throw new Error("Success notice not shown");
    const hasCard = await page.$(".stamp-card");
    if (!hasCard) throw new Error("No stamp card appeared in gallery");
  });

  await test("Stamp show page displays all sections", async () => {
    await page.goto(BASE_URL);
    await page.waitForSelector(".stamp-card a");

    await page.click(".stamp-card a");
    await page.waitForSelector("h2");
    await page.waitForTimeout(300);

    const body = await page.textContent("body");
    if (!body.includes("Stamp:")) throw new Error("Stamp detail heading not found");
    if (!body.includes("Details")) throw new Error("Details section not found");
    if (!body.includes("Update Time")) throw new Error("Update Time section not found");
    if (!body.includes("Time History")) throw new Error("Time History section not found");
    if (!body.includes("Delete")) throw new Error("Delete button not found");

    const previewImg = await page.$("img");
    if (!previewImg) throw new Error("Preview image not rendered");

    const src = await previewImg.getAttribute("src");
    if (!src || !src.includes("/preview")) throw new Error("Preview image src missing or wrong");
  });

  await test("Edit time updates the stamp and creates history log", async () => {
    await page.goto(BASE_URL);
    await page.waitForSelector(".stamp-card a");
    await page.click(".stamp-card a");
    await page.waitForSelector("h2");

    await page.fill("#annotated_seconds", "");
    await page.type("#annotated_seconds", "123");
    await page.click('input[value="Update Time"]');

    await page.waitForURL("**/stamps/**");
    await page.waitForTimeout(500);

    const body = await page.textContent("body");
    if (!body.includes("Time updated")) throw new Error("Time updated notice not shown");
    if (!body.includes("1:23")) throw new Error("Formatted time 1:23 not found in history");
  });

  await test("Delete stamp removes it from gallery", async () => {
    await page.goto(BASE_URL);
    await page.waitForSelector(".stamp-card a");
    await page.click(".stamp-card a");
    await page.waitForSelector("h2");

    await page.click('button:has-text("Delete")');
    await page.waitForURL("**/stamps");
    await page.waitForTimeout(500);

    const body = await page.textContent("body");
    if (!body.includes("Stamp deleted")) throw new Error("Delete notice not shown");
    const hasCard = await page.$(".stamp-card");
    if (hasCard) throw new Error("Stamp card still visible after delete");
  });

  await test("Empty gallery shows fallback message", async () => {
    await page.goto(BASE_URL);
    await page.waitForTimeout(500);
    const body = await page.textContent("body");
    const hasCard = await page.$(".stamp-card");
    if (hasCard) {
      const count = await page.$$eval(".stamp-card", els => els.length);
      await page.waitForSelector('h2');
    } else {
      if (!body.includes("No stamps uploaded yet")) throw new Error("Fallback message not shown");
    }
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
