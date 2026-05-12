const { chromium } = require("playwright");
const path = require("path");
const fs = require("fs");

const BASE_URL = "http://localhost:3000";
const HEADED = process.argv.includes("--headed") || process.argv.includes("-h");

async function run() {
  const browser = await chromium.launch({ headless: !HEADED, slowMo: HEADED ? 300 : 0 });
  const context = await browser.newContext();
  const page = await context.newPage();
  const consoleErrors = [];

  page.on("console", (msg) => {
    if (msg.type() === "error") {
      consoleErrors.push(msg.text());
    }
  });

  page.on("pageerror", (err) => {
    consoleErrors.push(`PAGE ERROR: ${err.message}`);
  });

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

  await test("Clicking drop zone triggers hidden file input", async () => {
    await page.goto(BASE_URL);
    const dropzone = await page.$(".upload-dropzone");
    if (!dropzone) throw new Error("Drop zone not found");

    const clicked = await page.evaluate(() => {
      return new Promise((resolve) => {
        const input = document.querySelector('input[type="file"]');
        if (!input) { resolve(false); return; }
        input.addEventListener("click", () => resolve(true), { once: true });
        document.querySelector(".upload-dropzone").click();
        setTimeout(() => resolve(false), 500);
      });
    });
    if (!clicked) throw new Error("Drop zone click did not trigger file input click");
  });

  await test("Drop zone shows dragover style", async () => {
    await page.goto(BASE_URL);
    const dropzone = await page.$(".upload-dropzone");
    if (!dropzone) throw new Error("Drop zone not found");

    await dropzone.dispatchEvent("dragenter");
    await page.waitForTimeout(100);
    const hasClass = await page.$eval(".upload-dropzone", el => el.classList.contains("dragover"));
    if (!hasClass) throw new Error("dragover class not applied");

    await dropzone.dispatchEvent("dragleave");
    await page.waitForTimeout(100);
    const stillHas = await page.$eval(".upload-dropzone", el => el.classList.contains("dragover"));
    if (stillHas) throw new Error("dragover class not removed on dragleave");
  });

  await test("File list shows after selecting a file", async () => {
    await page.goto(BASE_URL);
    const fileInput = await page.$('input[type="file"]');
    if (!fileInput) throw new Error("File input not found");

    await fileInput.setInputFiles(testImagePath);
    const fileList = await page.$(".upload-file-list");
    const html = await fileList.innerHTML();
    if (!html.includes("test-image")) throw new Error("Selected file not shown in file list");
  });

  await test("Remove button clears file from list", async () => {
    await page.goto(BASE_URL);
    const fileInput = await page.$('input[type="file"]');
    await fileInput.setInputFiles(testImagePath);

    const removeBtn = await page.$(".upload-file-remove");
    if (!removeBtn) throw new Error("Remove button not found");
    await removeBtn.click();
    await page.waitForTimeout(100);

    const fileList = await page.$(".upload-file-list");
    const html = await fileList.innerHTML();
    if (html.includes("test-image")) throw new Error("File still shown after remove");
  });

  await test("Upload multiple files creates stamps in gallery", async () => {
    await page.goto(BASE_URL);
    const fileInput = await page.$('input[type="file"]');
    if (!fileInput) throw new Error("File input not found");

    const secondImagePath = path.join(__dirname, "multi-frame-test.tif");
    await fileInput.setInputFiles([testImagePath, secondImagePath]);

    const fileList = await page.$(".upload-file-list");
    const html = await fileList.innerHTML();
    if (!html.includes("test-image")) throw new Error("First file not in list");
    if (!html.includes("multi-frame-test")) throw new Error("Second file not in list");

    await page.click('input[type="submit"]');
    await page.waitForTimeout(3000);

    const stampCards = await page.$$(".stamp-card");
    if (stampCards.length < 2) throw new Error("Less than 2 stamp cards after multi-upload");
  });

  await test("Upload a file creates a stamp visible in gallery", async () => {
    await page.goto(BASE_URL);
    const fileInput = await page.$('input[type="file"]');
    if (!fileInput) throw new Error("File input not found");

    await fileInput.setInputFiles(testImagePath);

    const fileList = await page.$(".upload-file-list");
    const listHtml = await fileList.innerHTML();
    if (!listHtml.includes("test-image")) throw new Error("File not shown in list after selection");

    await page.click('input[type="submit"]');

    await page.waitForTimeout(1500);

    await page.waitForSelector(".stamp-card", { timeout: 10000 });
    const body = await page.textContent("body");
    if (!body.includes("test-image")) throw new Error("Uploaded file not found in gallery");
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
    const initialCount = await page.$$eval(".stamp-card", els => els.length);

    await page.waitForSelector(".stamp-card a");
    await page.click(".stamp-card a");
    await page.waitForSelector("h2");

    await page.click('button:has-text("Delete")');
    await page.waitForURL("**/stamps");
    await page.waitForTimeout(500);

    const body = await page.textContent("body");
    if (!body.includes("Stamp deleted")) throw new Error("Delete notice not shown");

    const newCount = await page.$$eval(".stamp-card", els => els.length);
    if (newCount >= initialCount) throw new Error("Stamp count did not decrease after delete");
  });

  await test("Gallery shows stamps or fallback message", async () => {
    await page.goto(BASE_URL);
    await page.waitForTimeout(500);
    const body = await page.textContent("body");
    const hasCard = await page.$(".stamp-card");
    if (hasCard) {
      if (!body.includes("Stamp Tracker")) throw new Error("Gallery heading not shown");
    } else {
      if (!body.includes("No stamps uploaded yet")) throw new Error("Fallback message not shown");
    }
  });

  const summary = `\nResults: ${passed} passed, ${failed} failed, ${passed + failed} total\n`;
  console.log(summary);

  if (consoleErrors.length > 0) {
    console.log("Console errors:");
    for (const err of [...new Set(consoleErrors)].slice(0, 10)) {
      console.log(`  ${err}`);
    }
    console.log("");
  }

  await browser.close();
  process.exit(failed > 0 ? 1 : 0);
}

run().catch((err) => {
  console.error("Fatal:", err);
  process.exit(1);
});
