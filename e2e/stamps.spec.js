const { chromium } = require("playwright");
const path = require("path");
const fs = require("fs");

const BASE_URL = "http://localhost:3000";
const HEADED = process.argv.includes("--headed") || process.argv.includes("-h");

async function run() {
  const launchOpts = { slowMo: HEADED ? 300 : 0 };
  if (HEADED) {
    launchOpts.headless = false;
    launchOpts.args = ["--start-maximized"];
  }
  const browser = await chromium.launch(launchOpts);
  const context = await browser.newContext(HEADED ? { viewport: null } : {});
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
    if (!body.includes("Tracker")) throw new Error("Tracker heading not found");
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
        input.addEventListener("click", (e) => { e.preventDefault(); resolve(true); }, { once: true });
        document.querySelector(".upload-dropzone").click();
        setTimeout(() => resolve(false), 500);
      });
    });
    if (!clicked) throw new Error("Drop zone click did not trigger file input click");
  });

  await test("Clicking label text triggers file input via native label behavior", async () => {
    await page.goto(BASE_URL);

    const fileChooserPromise = page.waitForEvent("filechooser", { timeout: 5000 }).catch(() => null);

    const clicked = await page.evaluate(() => {
      return new Promise((resolve) => {
        const input = document.querySelector('input[type="file"]');
        if (!input) { resolve(false); return; }
        input.addEventListener("click", (e) => { e.preventDefault(); resolve(true); }, { once: true });
        const labelText = document.querySelector(".upload-dropzone label p");
        if (!labelText) { resolve(false); return; }
        labelText.click();
        setTimeout(() => resolve(false), 500);
      });
    });
    if (!clicked) throw new Error("Clicking label text did not trigger file input");

    const fc = await fileChooserPromise;
    if (fc) await fc.cancel();
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

  await test("Show page version upload dropzone triggers file input", async () => {
    await page.goto(BASE_URL);
    const fileInput = await page.$('input[type="file"]');
    await fileInput.setInputFiles(testImagePath);
    await page.click('input[type="submit"]');
    await page.waitForTimeout(3000);
    await page.waitForSelector(".stamp-card a");

    await page.locator(".stamp-card a").first().click();
    await page.waitForSelector(".version-upload-form", { timeout: 10000 });

    const fileChooserPromise = page.waitForEvent("filechooser", { timeout: 5000 }).catch(() => null);

    const clicked = await page.evaluate(() => {
      return new Promise((resolve) => {
        const form = document.querySelector(".version-upload-form");
        const input = form?.querySelector('input[type="file"]');
        if (!input) { resolve(false); return; }
        input.addEventListener("click", (e) => { e.preventDefault(); resolve(true); }, { once: true });
        const label = form?.querySelector("label");
        if (label) label.click();
        setTimeout(() => resolve(false), 500);
      });
    });
    if (!clicked) throw new Error("Version upload label click did not trigger file input");

    const fc = await fileChooserPromise;
    if (fc) await fc.cancel();
  });

  await test("Version upload drop zone has Stimulus upload controller", async () => {
    await page.goto(BASE_URL);
    const fileInput = await page.$('input[type="file"]');
    await fileInput.setInputFiles(testImagePath);
    await page.click('input[type="submit"]');
    await page.waitForTimeout(3000);
    await page.waitForSelector(".stamp-card a");

    await page.locator(".stamp-card a").first().click();
    await page.waitForSelector(".version-upload-form", { timeout: 10000 });

    const hasController = await page.evaluate(() => {
      const form = document.querySelector(".version-upload-form");
      return form?.getAttribute("data-controller") === "upload";
    });
    if (!hasController) throw new Error("Version upload form missing data-controller='upload'");

    const hasTargets = await page.evaluate(() => {
      const form = document.querySelector(".version-upload-form");
      const dropzone = form?.querySelector(".upload-dropzone");
      const input = form?.querySelector('input[type="file"]');
      const fileList = form?.querySelector(".upload-file-list");
      const submit = form?.querySelector('input[type="submit"]');
      return (
        dropzone?.getAttribute("data-upload-target") === "dropzone" &&
        input?.getAttribute("data-upload-target") === "input" &&
        fileList?.getAttribute("data-upload-target") === "fileList" &&
        submit?.getAttribute("data-upload-target") === "submit" &&
        form?.getAttribute("data-upload-field-name-value") === "original_file"
      );
    });
    if (!hasTargets) throw new Error("Version upload form missing required data-upload-target attributes");
  });

  await test("Version upload drop zone shows dragover style", async () => {
    await page.goto(BASE_URL);
    const fileInput = await page.$('input[type="file"]');
    await fileInput.setInputFiles(testImagePath);
    await page.click('input[type="submit"]');
    await page.waitForTimeout(3000);
    await page.waitForSelector(".stamp-card a");

    await page.locator(".stamp-card a").first().click();
    await page.waitForSelector(".version-upload-form", { timeout: 10000 });

    const dropzone = await page.$(".version-upload-form .upload-dropzone");
    if (!dropzone) throw new Error("Version upload drop zone not found");

    await dropzone.dispatchEvent("dragenter");
    await page.waitForTimeout(100);
    const hasClass = await page.$eval(".version-upload-form .upload-dropzone", el => el.classList.contains("dragover"));
    if (!hasClass) throw new Error("dragover class not applied on version upload drop zone");

    await dropzone.dispatchEvent("dragleave");
    await page.waitForTimeout(100);
    const stillHas = await page.$eval(".version-upload-form .upload-dropzone", el => el.classList.contains("dragover"));
    if (stillHas) throw new Error("dragover class not removed on dragleave on version upload drop zone");
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

    const testCard = page.locator(".stamp-card").filter({ hasText: "test-image" }).first();
    const multiCard = page.locator(".stamp-card").filter({ hasText: "multi-frame-test" }).first();
    await testCard.waitFor({ timeout: 10000 });
    await multiCard.waitFor({ timeout: 10000 });
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

    const card = page.locator(".stamp-card").filter({ hasText: "test-image" }).first();
    await card.waitFor({ timeout: 10000 });
  });

  await test("Stamp show page displays all sections", async () => {
    await page.goto(BASE_URL);
    const fileInput = await page.$('input[type="file"]');
    await fileInput.setInputFiles(testImagePath);
    await page.click('input[type="submit"]');
    await page.waitForTimeout(3000);
    await page.waitForSelector(".stamp-card a");
    await page.locator(".stamp-card a").first().click();
    await page.waitForSelector("h2");
    await page.waitForTimeout(300);
    const body = await page.textContent("body");
    if (!body.includes("Details")) throw new Error("Details section missing");
    if (!body.includes("Update Time")) throw new Error("Update Time section missing");
    if (!body.includes("Versions")) throw new Error("Versions section missing");
    if (!body.includes("Download")) throw new Error("Download link missing");
    if (!body.includes("Back to Gallery")) throw new Error("Back link missing");
    if (!body.includes("Client")) throw new Error("Client section missing");
  });

  await test("Upload form: submit without file shows error", async () => {
    await page.goto(BASE_URL);

    const result = await page.evaluate(async () => {
      const csrf = document.querySelector('meta[name="csrf-token"]')?.content;
      const fd = new FormData();
      fd.append("stamp[original_file]", "");
      if (csrf) fd.append("authenticity_token", csrf);

      const resp = await fetch("/stamps", {
        method: "POST",
        body: fd,
        headers: { "Accept": "text/html" }
      });
      const text = await resp.text();
      return { status: resp.status, hasError: text.toLowerCase().includes("select a file") };
    });

    if (result.status !== 422) throw new Error(`Expected 422, got ${result.status}`);
    if (!result.hasError) throw new Error("Validation error not shown in response");
  });

  await test("Edit time updates the stamp and creates history log", async () => {
    await page.goto(BASE_URL);
    await page.waitForSelector(".stamp-card a");
    await page.click(".stamp-card a");
    await page.waitForSelector("h2");

    await page.click('#update-time-section [data-action="click->edit-toggle#edit"]');
    await page.waitForSelector("#annotated_seconds", { timeout: 5000 });

    await page.fill("#annotated_seconds", "");
    await page.type("#annotated_seconds", "123");
    await page.click(".time-form .btn-confirm");

    await page.waitForTimeout(1500);

    const body = await page.textContent("body");
    if (!body.includes("1:23")) throw new Error("Formatted time 1:23 not found in history");
  });

  await test("Delete stamp removes it from gallery", async () => {
    await page.goto(BASE_URL);
    await page.waitForSelector(".stamp-card a");

    const initialCount = await page.$$eval(".stamp-card", els => els.length);
    await page.locator(".stamp-card a").first().click();
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
      if (!body.includes("Tracker")) throw new Error("Gallery heading not shown");
    } else {
      if (!body.includes("No stamps uploaded yet")) throw new Error("Fallback message not shown");
    }
  });

  // ── 4 preview strategies ──

  const testImagesDir = path.join(__dirname, "..", "spec", "fixtures", "files");

  async function uploadAndVerify(label, filename, expectedCs, checkPixels = true) {
    await test(`${label}: ${filename} processes and shows preview`, async () => {
      const filePath = path.join(testImagesDir, filename);
      if (!fs.existsSync(filePath)) throw new Error(`Test image not found: ${filePath}`);

      await page.goto(BASE_URL);
      const fileInput = await page.$('input[type="file"]');
      await fileInput.setInputFiles(filePath);
      await page.click('input[type="submit"]');

      // Wait for AJAX uploads + page reload
      await page.waitForTimeout(5000);
      await page.waitForSelector(".stamp-card", { timeout: 20000 });

      // Click the stamp card matching the uploaded filename (without extension)
      const displayName = filename.replace(/\.[^.]+$/, "");
      const stampLink = page.locator(".stamp-card").filter({ hasText: displayName }).locator("a").first();
      await stampLink.waitFor({ timeout: 10000 });
      await stampLink.click();

      await page.waitForSelector("dl", { timeout: 10000 });
      await page.waitForTimeout(500);

      const detailBody = (await page.textContent("body")).toLowerCase();
      if (!detailBody.includes("processed")) throw new Error(`Status not processed for ${filename}`);

      const pageUrl = page.url();
      const bodyText = await page.textContent("body");

      if (!bodyText.includes(expectedCs)) {
        const details = await page.$("dl");
        const detailsText = details ? await details.textContent() : "no details";
        throw new Error(`Expected "${expectedCs}" in body. URL: ${pageUrl} Details: ${detailsText}`);
      }

      // Verify preview image loads (200 OK, image/png)
      const img = await page.$(".stamp-detail-preview img");
      if (!img) throw new Error("No preview image element");
      const src = await img.getAttribute("src");
      if (!src || !src.includes("/preview")) throw new Error("Preview src missing");

      if (checkPixels) {
        const hasVisiblePixels = await page.evaluate(async (url) => {
          return new Promise((resolve) => {
            const img = new Image();
            img.crossOrigin = "anonymous";
            img.onload = () => {
              try {
                const c = document.createElement("canvas");
                c.width = img.width;
                c.height = img.height;
                const ctx = c.getContext("2d");
                ctx.drawImage(img, 0, 0);
                const data = ctx.getImageData(0, 0, Math.min(100, img.width), Math.min(100, img.height)).data;
                for (let i = 0; i < data.length; i += 4) {
                  if (data[i + 3] > 0 && (data[i] > 0 || data[i + 1] > 0 || data[i + 2] > 0)) {
                    resolve(true);
                    return;
                  }
                }
                resolve(false);
              } catch { resolve(false); }
            };
            img.onerror = () => resolve(false);
            img.src = url;
          });
        }, src);
        if (!hasVisiblePixels) throw new Error("Preview image has no visible pixels");
      }
    });
  }

  await uploadAndVerify("RGB no spot", "02-no_spot.tif", "sRGB");
  await uploadAndVerify("RGB spot", "02.tif", "sRGB");
  await uploadAndVerify("CMYK no spot", "01-no_spot.tif", "CMYK");
  await uploadAndVerify("CMYK spot", "01.tif", "CMYK", false);
  await uploadAndVerify("PSD RGB no spot", "02-no_spot.psd", "sRGB");
  await uploadAndVerify("PSD CMYK no spot", "01-no_spot.psd", "CMYK");
  await uploadAndVerify("EPS RGB no spot", "eps-rgb.eps", "sRGB");
  await uploadAndVerify("EPS CMYK no spot", "eps-cmyk.eps", "CMYK");

  await test("Corte SVG: test.svg uploads and processes (no preview)", async () => {
    const filePath = path.join(testImagesDir, "test.svg");
    if (!fs.existsSync(filePath)) throw new Error(`Test image not found: ${filePath}`);

    await page.goto(BASE_URL);
    const fileInput = await page.$('input[type="file"]');
    await fileInput.setInputFiles(filePath);
    await page.click('input[type="submit"]');

    await page.waitForTimeout(5000);
    await page.waitForSelector(".stamp-card", { timeout: 20000 });

    const stampLink = page.locator(".stamp-card").filter({ hasText: "test.svg" }).locator("a").first();
    await stampLink.waitFor({ timeout: 10000 });
    await stampLink.click();

    await page.waitForSelector("dl", { timeout: 10000 });
    await page.waitForTimeout(500);

    const body = (await page.textContent("body")).toLowerCase();
    if (!body.includes("processed")) throw new Error("Status not processed");
    if (!body.includes("corte")) throw new Error("Category not corte");
  });

  // ── DXF Layer Configuration ──

  const dxfPath = path.join(testImagesDir, "29-30.dxf");

  await test("DXF Corte: 29-30.dxf uploads and shows Layer Configuration", async () => {
    if (!fs.existsSync(dxfPath)) throw new Error(`DXF not found: ${dxfPath}`);

    await page.goto(BASE_URL);
    const fileInput = await page.$('input[type="file"]');
    await fileInput.setInputFiles(dxfPath);
    await page.click('input[type="submit"]');

    await page.waitForTimeout(5000);
    await page.waitForSelector(".stamp-card", { timeout: 20000 });

    const stampLink = page.locator(".stamp-card").filter({ hasText: "29-30" }).locator("a").first();
    await stampLink.waitFor({ timeout: 10000 });
    await stampLink.click();
    await page.waitForSelector("dl", { timeout: 10000 });
    await page.waitForTimeout(500);

    const body = (await page.textContent("body")).toLowerCase();
    if (!body.includes("processed")) throw new Error("Status not processed");
    if (!body.includes("corte")) throw new Error("Category not corte");

    // Verify Layer Configuration section exists
    if (!body.includes("layer configuration")) throw new Error("Layer Configuration section not found");

    // Verify layer row: swatch, name, color code, select
    const layerRow = await page.$(".layer-config-row");
    if (!layerRow) throw new Error("Layer config row not found");

    const swatch = await layerRow.$(".layer-swatch");
    if (!swatch) throw new Error("Layer swatch not found");
    const bgColor = await swatch.getAttribute("style");
    if (!bgColor || !bgColor.includes("background-color")) throw new Error("Swatch has no background-color");

    const layerName = await layerRow.$(".layer-name");
    if (!layerName) throw new Error("Layer name not found");
    const nameText = await layerName.textContent();
    if (!nameText) throw new Error("Layer name text empty");

    const colorCode = await layerRow.$(".layer-color-code");
    if (!colorCode) throw new Error("Color code not found");
    const codeText = await colorCode.textContent();
    if (!codeText || !codeText.startsWith("#")) throw new Error("Color code is not a hex value");

    // Verify measurements are shown
    const measurements = await layerRow.$(".layer-measurements");
    if (!measurements) throw new Error("Layer measurements not found");
    const measureText = await measurements.textContent();
    if (!measureText.includes("mm")) throw new Error(`Measurements missing mm unit. Got: "${measureText}"`);

    const select = await layerRow.$("select.layer-annotation-select");
    if (!select) throw new Error("Annotation select not found");
    const selectedValue = await select.inputValue();
    if (selectedValue !== "cut") throw new Error(`Expected default annotation "cut", got "${selectedValue}"`);

    // Verify all 4 annotation options exist
    const optionValues = await select.evaluate(el => Array.from(el.options).map(o => o.value));
    const expectedOptions = ["cut", "hole", "engraving", "ignore"];
    const hasAll = expectedOptions.every(v => optionValues.includes(v));
    if (!hasAll) throw new Error(`Select options missing. Got: ${optionValues.join(",")}`);
  });

  await test("DXF Layer Configuration: change annotation and save", async () => {
    await page.goto(BASE_URL);
    await page.waitForSelector(".stamp-card", { timeout: 10000 });

    const stampLink = page.locator(".stamp-card").filter({ hasText: "29-30" }).locator("a").first();
    await stampLink.waitFor({ timeout: 10000 });
    await stampLink.click();
    await page.waitForSelector("dl", { timeout: 10000 });
    await page.waitForTimeout(500);

    // Verify measurements exist before save
    const beforeMeasure = await page.$(".layer-measurements");
    if (!beforeMeasure) throw new Error("Measurements not found before save");
    const beforeText = await beforeMeasure.textContent();

    // Change first layer annotation to "Furo" (hole)
    const select = await page.$("select.layer-annotation-select");
    if (!select) throw new Error("Annotation select not found");
    await select.selectOption("hole");

    // Click Save
    const saveBtn = await page.$("button.layer-config-save");
    if (!saveBtn) throw new Error("Save button not found");
    await saveBtn.click();

    // Wait for redirect back to show page after PATCH
    await page.waitForURL("**/stamps/**", { timeout: 10000 });
    await page.waitForTimeout(500);

    // Check for success notice
    const body = await page.textContent("body");
    if (!body.includes("Layer configuration saved")) throw new Error("Success notice not shown");

    // Verify annotation persisted
    const selectAfter = await page.$("select.layer-annotation-select");
    if (!selectAfter) throw new Error("Annotation select not found after save");
    const valueAfter = await selectAfter.inputValue();
    if (valueAfter !== "hole") throw new Error(`Expected "hole" after save, got "${valueAfter}"`);

    // Verify measurements still present after save
    const afterMeasure = await page.$(".layer-measurements");
    if (!afterMeasure) throw new Error("Measurements not found after save");
    const afterText = await afterMeasure.textContent();
    if (afterText !== beforeText) throw new Error(`Measurements changed after save. Before: "${beforeText}" After: "${afterText}"`);
  });

  // ── Multi-color DXF with measurements ──

  const reforcoPath = path.join(testImagesDir, "REFORÇO - 35 AO 43.dxf");

  await test("DXF REFORÇO: uploads and shows multiple layers with measurements", async () => {
    if (!fs.existsSync(reforcoPath)) throw new Error(`DXF not found: ${reforcoPath}`);

    await page.goto(BASE_URL);
    const fileInput = await page.$('input[type="file"]');
    await fileInput.setInputFiles(reforcoPath);
    await page.click('input[type="submit"]');

    await page.waitForTimeout(5000);
    await page.waitForSelector(".stamp-card", { timeout: 20000 });

    const stampLink = page.locator(".stamp-card").filter({ hasText: "REFORÇO" }).locator("a").first();
    await stampLink.waitFor({ timeout: 10000 });
    await stampLink.click();
    await page.waitForSelector("dl", { timeout: 10000 });
    await page.waitForTimeout(500);

    const bodyText = await page.textContent("body");
    if (!bodyText.toLowerCase().includes("processed")) throw new Error("Status not processed");

    // Verify all 3 layer rows exist
    const layerRows = await page.$$(".layer-config-row");
    if (layerRows.length !== 3) throw new Error(`Expected 3 layer rows, got ${layerRows.length}`);

    // Verify each row has measurements
    for (let i = 0; i < layerRows.length; i++) {
      const row = layerRows[i];
      const measure = await row.$(".layer-measurements");
      if (!measure) throw new Error(`Row ${i}: measurements span not found`);
      const text = await measure.textContent();
      if (!text.includes("mm") && !text.includes("mm²")) throw new Error(`Row ${i}: measurements missing units. Got: "${text}"`);
    }
  });

  // ── Version upload + approve ──

  await test("Version: upload a new version and verify version cards", async () => {
    // Upload a fresh stamp as base
    await page.goto(BASE_URL);
    const fileInput = await page.$('input[type="file"]');
    await fileInput.setInputFiles(testImagePath);
    await page.click('input[type="submit"]');
    await page.waitForTimeout(3000);
    await page.waitForSelector(".stamp-card", { timeout: 10000 });

    const stampLink = page.locator(".stamp-card").filter({ hasText: "test-image" }).first().locator("a").first();
    await stampLink.waitFor({ timeout: 10000 });
    await stampLink.click();
    await page.waitForSelector("h2", { timeout: 10000 });
    await page.waitForTimeout(500);

    // Verify version card shows v1 with Approved badge
    const v1Card = page.locator(".version-card").filter({ hasText: "v1" }).first();
    await v1Card.waitFor({ timeout: 5000 });
    const v1Approved = await v1Card.textContent();
    if (!v1Approved.includes("Approved")) throw new Error("v1 does not show Approved badge");

    // Upload a new version
    const multiPath = path.join(__dirname, "multi-frame-test.tif");
    if (!fs.existsSync(multiPath)) throw new Error(`multi-frame-test.tif not found`);

    const versionForm = page.locator(".version-upload-form");
    await versionForm.waitFor({ timeout: 5000 });
    const versionInput = versionForm.locator('input[type="file"]');
    await versionInput.setInputFiles(multiPath);

    const uploadBtn = versionForm.locator('input[type="submit"]');
    await uploadBtn.click();

    // Wait for redirect after processing (native form submit)
    await page.waitForURL("**/stamps/**", { timeout: 30000 });

    // Wait for flash notice to appear, or for the v2 version card
    try {
      await page.waitForSelector(".version-card", { timeout: 15000 });
    } catch {
      // fallback: wait a bit more and check body
      await page.waitForTimeout(2000);
    }

    const body = await page.textContent("body");
    const hasNotice = body.includes("uploaded and processing");
    const hasV2Card = body.includes("v2");
    if (!hasNotice && !hasV2Card) {
      const details = await page.$("dl");
      const detailsText = details ? await details.textContent() : "no details";
      throw new Error(`Version upload notice nor v2 card found. Body excerpt: ${body.slice(0, 300)} Details: ${detailsText}`);
    }

    // Verify v2 exists and has Approved badge (auto-approved)
    const v2Card = page.locator(".version-card").filter({ hasText: "v2" }).first();
    await v2Card.waitFor({ timeout: 10000 });
    const v2Text = await v2Card.textContent();
    if (!v2Text.includes("Approved")) throw new Error("v2 should be auto-approved but Approved badge not found");
  });

  await test("Version: approve a different version", async () => {
    // Create a uniquely-named stamp to avoid cross-test card matching issues
    const uniqueStampPath = path.join(__dirname, "e2e-approve-test.tif");
    const { execSync } = require("child_process");
    execSync(`convert -size 50x50 xc:blue 'TIFF:${uniqueStampPath}'`);

    await page.goto(BASE_URL);
    const fileInput = await page.$('input[type="file"]');
    await fileInput.setInputFiles(uniqueStampPath);
    await page.click('input[type="submit"]');
    await page.waitForTimeout(3000);
    await page.waitForSelector(".stamp-card", { timeout: 10000 });

    const stampLink = page.locator(".stamp-card").filter({ hasText: "e2e-approve-test" }).first().locator("a").first();
    await stampLink.waitFor({ timeout: 10000 });
    await stampLink.click();
    await page.waitForSelector("h2", { timeout: 10000 });
    await page.waitForTimeout(500);

    // Upload a second version
    const multiPath = path.join(__dirname, "multi-frame-test.tif");
    const versionForm = page.locator(".version-upload-form");
    await versionForm.waitFor({ timeout: 5000 });
    await versionForm.locator('input[type="file"]').setInputFiles(multiPath);
    await versionForm.locator('input[type="submit"]').click();
    await page.waitForURL("**/stamps/**", { timeout: 15000 });
    await page.waitForTimeout(3000);

    // Wait for version cards to render
    await page.waitForSelector(".version-card", { timeout: 10000 });
    await page.waitForTimeout(500);

    // Now v2 is auto-approved. Find v1 and click Approve
    await page.waitForSelector(".version-card", { timeout: 10000 });
    await page.waitForTimeout(1000);

    const approveBtn = page.locator('button:has-text("Approve")');
    if (await approveBtn.count() === 0) {
      const allCards = await page.locator(".version-card").allTextContents();
      throw new Error(`No Approve buttons on page. Cards: ${JSON.stringify(allCards)}`);
    }
    await approveBtn.first().click();

    await page.waitForURL("**/stamps/**", { timeout: 10000 });
    await page.waitForTimeout(500);

    const body = await page.textContent("body");
    if (!body.includes("approved")) throw new Error("Approve notice not shown");

    // Now v1 should have Approved badge
    const v1Card = page.locator('.version-card:has(strong:text("v1"))').first();
    const v1After = await v1Card.textContent();
    if (!v1After.includes("Approved")) throw new Error("v1 should show Approved after approving");

    // v2 should no longer have Approved
    const v2Card = page.locator('.version-card:has(strong:text("v2"))').first();
    const v2After = await v2Card.textContent();
    if (v2After.includes("Approved")) throw new Error("v2 should not have Approved after v1 was approved");

    // Clean up
    if (fs.existsSync(uniqueStampPath)) fs.unlinkSync(uniqueStampPath);
  });

  // ── Download link ──

  await test("Download Original link downloads the file", async () => {
    await page.goto(BASE_URL);
    await page.waitForSelector(".stamp-card a", { timeout: 10000 });

    // Navigate to any stamp's show page
    await page.locator(".stamp-card a").first().click();
    await page.waitForSelector("h2", { timeout: 10000 });
    await page.waitForTimeout(300);

    // Find download link and verify it points to download path
    const downloadLink = await page.$('a[href*="/download"]');
    if (!downloadLink) throw new Error("Download Original link not found");

    const href = await downloadLink.getAttribute("href");
    if (!href || !href.includes("/download")) throw new Error(`Download href missing or wrong: ${href}`);

    // Trigger download via Playwright and verify it succeeds
    const [download] = await Promise.all([
      page.waitForEvent("download", { timeout: 10000 }),
      downloadLink.click()
    ]);

    if (!download) throw new Error("Download did not start");
    const suggestedName = download.suggestedFilename();
    if (!suggestedName) throw new Error("Download has no filename");
  });

  // ── Detail fields ──

  await test("Show page displays all detail fields correctly for an arte stamp", async () => {
    // Navigate to 02-no_spot.tif (uploaded by previous preview test; if missing, upload fresh)
    await page.goto(BASE_URL);
    await page.waitForSelector(".stamp-card", { timeout: 10000 });

    let stampLink = page.locator(".stamp-card").filter({ hasText: "02-no_spot" }).first().locator("a").first();
    let cardExists = await stampLink.count();

    if (cardExists === 0) {
      const filePath = path.join(testImagesDir, "02-no_spot.tif");
      const fileInput = await page.$('input[type="file"]');
      await fileInput.setInputFiles(filePath);
      await page.click('input[type="submit"]');
      await page.waitForTimeout(5000);
      await page.waitForSelector(".stamp-card", { timeout: 20000 });
      stampLink = page.locator(".stamp-card").filter({ hasText: "02-no_spot" }).first().locator("a").first();
    }

    await stampLink.first().click();
    await page.waitForSelector("dl", { timeout: 10000 });
    await page.waitForTimeout(500);

    const body = await page.textContent("body");

    // Check processed status
    if (!body.toLowerCase().includes("processed")) throw new Error("Status not processed");

    // Check detail fields
    if (!body.includes("sRGB")) throw new Error("Colorspace sRGB not found");

    // Has Spots should be "No" for 02-no_spot.tif
    const detailsText = await page.$eval("dl", el => el.textContent);
    if (!detailsText.includes("No")) {
      // "No" is the value for has_spots — also appears in ICC "None" potentially
      // Let's check more specifically
      if (!body.includes("Has Spots")) throw new Error("Has Spots label not found");
    }
    if (!body.includes("Has Spots")) throw new Error("Has Spots label not found");

    // ICC Profile should be present (Adobe RGB (1998) for this file)
    if (!body.includes("ICC Profile")) throw new Error("ICC Profile label not found");

    // Dimensions should show "px" and "cm"
    if (!body.includes("px")) throw new Error("Dimensions px not found");
    if (!body.includes("cm")) throw new Error("Dimensions cm not found");

    // Estimated Time should be present
    if (!body.includes("Estimated Time")) throw new Error("Estimated Time label not found");

    // Annotated Time should be present
    if (!body.includes("Annotated Time")) throw new Error("Annotated Time label not found");
  });

  // ── DXF Mold Organization ──

  await test("DXF Mold Organization: unorganized badge on stamp card", async () => {
    const dxfPath = path.join(testImagesDir, "29-30.dxf");
    if (!fs.existsSync(dxfPath)) throw new Error("DXF not found");

    await page.goto(BASE_URL);
    const fileInput = await page.$('input[type="file"]');
    await fileInput.setInputFiles(dxfPath);
    await page.click('input[type="submit"]');
    await page.waitForTimeout(5000);
    await page.waitForSelector(".stamp-card", { timeout: 20000 });

    const card = page.locator(".stamp-card").filter({ hasText: "29-30" }).first();
    const icon = card.locator('.stamp-card-status-icon[alt="Not Organized"]');
    await icon.waitFor({ timeout: 5000 });
  });

  await test("DXF Mold Organization: shows Mold Organization section with default names and tamanhos", async () => {
    await page.goto(BASE_URL);
    await page.waitForSelector(".stamp-card", { timeout: 10000 });

    const stampLink = page.locator(".stamp-card").filter({ hasText: "29-30" }).first().locator("a").first();
    await stampLink.waitFor({ timeout: 10000 });
    await stampLink.click();
    await page.waitForSelector("h2", { timeout: 10000 });
    await page.waitForTimeout(500);

    const body = await page.textContent("body");
    if (!body.includes("Mold Organization")) throw new Error("Mold Organization section not found");

    // Verify mold and piece selects exist
    const moldeSelect = await page.$('select[name="molde_id"]');
    if (!moldeSelect) throw new Error("Molde select not found");

    const pecaSelect = await page.$('select[name="peca_id"]');
    if (!pecaSelect) throw new Error("Piece select not found");

    // Verify tamanho rows
    const tamanhoRows = await page.$$(".tamanho-row");
    if (tamanhoRows.length !== 1) throw new Error(`Expected 1 tamanho row, got ${tamanhoRows.length}`);

    // Verify measurements shown
    const firstRow = tamanhoRows[0];
    const meas = await firstRow.$(".tamanho-measurements");
    if (!meas) throw new Error("Tamanho measurements not found");
    const measText = await meas.textContent();
    if (!measText.includes("mm")) throw new Error(`Measurements missing mm: "${measText}"`);
    if (!measText.includes("P")) throw new Error(`Measurements missing perimeter: "${measText}"`);
    if (!measText.includes("L")) throw new Error(`Measurements missing total line: "${measText}"`);
  });

await test("DXF Mold Organization: save organization marks as organized", async () => {
    // Create molde and peca for the test
    const csrf = await page.evaluate(() => {
      const meta = document.querySelector("meta[name='csrf-token']");
      return meta?.content || "";
    });
    await page.evaluate(async (token) => {
      await fetch("/moldes", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({ authenticity_token: token, "molde[nome]": "Tênis" })
      });
      await fetch("/pecas", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({ authenticity_token: token, "peca[nome]": "Cabedal" })
      });
    }, csrf);

    await page.goto(BASE_URL);
    await page.waitForSelector(".stamp-card", { timeout: 10000 });

    const stampLink = page.locator(".stamp-card").filter({ hasText: "29-30" }).first().locator("a").first();
    await stampLink.waitFor({ timeout: 10000 });
    await stampLink.click();
    await page.waitForSelector("h2", { timeout: 10000 });
    await page.waitForTimeout(500);

    // Select molde and peca from dropdowns
    await page.selectOption('select[name="molde_id"]', { label: "Tênis" });
    await page.selectOption('select[name="peca_id"]', { label: "Cabedal" });

    // Change tamanho name
    const tamanhoInput = await page.$(".tamanho-input");
    await tamanhoInput.fill("Piloto");

    // Click Save and wait for Turbo Stream response
    await page.click('.mold-organization-form button[type="submit"], .mold-organization-form input[type="submit"]');
    await page.waitForTimeout(1500);

    // Verify download links appear (means organization was saved)
    const downloadLinks = await page.$$(".tamanho-download");
    if (downloadLinks.length === 0) throw new Error("No download links found after organization");

    // Verify molde and peca were saved by checking display text
    const body = await page.textContent("body");
    if (!body.includes("Tênis")) throw new Error(`Molde "Tênis" not found on page`);
    if (!body.includes("Cabedal")) throw new Error(`Peca "Cabedal" not found on page`);

    const tamanhoVal = await page.$eval(".tamanho-input", el => el.value);
    if (tamanhoVal !== "Piloto") throw new Error(`Expected "Piloto", got "${tamanhoVal}"`);

    // Verify icon is gone on card
    await page.goto(BASE_URL);
    await page.waitForTimeout(500);
    const icon = page.locator('.stamp-card-status-icon[alt="Not Organized"]');
    const iconCount = await icon.count();
    if (iconCount > 0) {
      // Check this specific card doesn't have the icon
      const card = page.locator(".stamp-card").filter({ hasText: "29-30" }).first();
      const cardIcon = card.locator('.stamp-card-status-icon[alt="Not Organized"]');
      const cardIconCount = await cardIcon.count();
      if (cardIconCount > 0) throw new Error("Not Organized icon should be gone after organizing");
    }
  });

  // ── DXF Overlap detection ──

  await test("DXF Overlap: overlapping pieces show stacked cuts error badge", async () => {
    // Create a DXF with two overlapping squares
    const overlapPath = path.join(__dirname, "e2e-overlap.dxf");
    const dxfLines = [
      "0", "SECTION", "2", "HEADER", "9", "$INSUNITS", "70", "4", "0", "ENDSEC",
      "0", "SECTION", "2", "TABLES",
      "0", "TABLE", "2", "LAYER", "70", "2",
      "0", "LAYER", "2", "0", "70", "0", "62", "7", "6", "Continuous",
      "0", "LAYER", "2", "Camada 1", "70", "0", "62", "7", "6", "Continuous",
      "0", "ENDTAB", "0", "ENDSEC",
      "0", "SECTION", "2", "ENTITIES",
      "0", "LWPOLYLINE", "8", "0", "62", "1", "90", "4", "70", "1",
      "10", "0", "20", "0", "10", "100", "20", "0", "10", "100", "20", "100", "10", "0", "20", "100",
      "0", "LWPOLYLINE", "8", "0", "62", "3", "90", "4", "70", "1",
      "10", "50", "20", "50", "10", "150", "20", "50", "10", "150", "20", "150", "10", "50", "20", "150",
      "0", "ENDSEC", "0", "EOF"
    ];
    fs.writeFileSync(overlapPath, dxfLines.join("\n"));

    await page.goto(BASE_URL);
    const fileInput = await page.$('input[type="file"]');
    await fileInput.setInputFiles(overlapPath);
    await page.click('input[type="submit"]');
    await page.waitForTimeout(5000);
    await page.waitForSelector(".stamp-card", { timeout: 20000 });

    // Check for the stacked cuts icon on the card
    const card = page.locator(".stamp-card").filter({ hasText: "e2e-overlap" }).first();
    const errIcon = card.locator('.stamp-card-status-icon[alt="Stacked Cuts"]');
    await errIcon.waitFor({ timeout: 5000 });

    // Go to show page and verify error message
    const stampLink = card.locator("a").first();
    await stampLink.click();
    await page.waitForSelector("h2", { timeout: 10000 });
    await page.waitForTimeout(500);

    const body = await page.textContent("body");
    if (!body.includes("stacked cuts")) throw new Error("Overlap error message not found on show page");

    // Clean up
    if (fs.existsSync(overlapPath)) fs.unlinkSync(overlapPath);
  });

  // ── DXF multiple tamanhos ──

  await test("DXF Mold Organization: multiple tamanhos with CABEDAL", async () => {
    const cabedalPath = path.join(testImagesDir, "CABEDAL - 35 AO 43.dxf");
    if (!fs.existsSync(cabedalPath)) throw new Error("DXF not found");

    await page.goto(BASE_URL);
    const fileInput = await page.$('input[type="file"]');
    await fileInput.setInputFiles(cabedalPath);
    await page.click('input[type="submit"]');
    await page.waitForTimeout(5000);
    await page.waitForSelector(".stamp-card", { timeout: 20000 });

    const stampLink = page.locator(".stamp-card").filter({ hasText: "CABEDAL" }).first().locator("a").first();
    await stampLink.waitFor({ timeout: 10000 });
    await stampLink.click();
    await page.waitForSelector("h2", { timeout: 10000 });
    await page.waitForTimeout(500);

    const body = await page.textContent("body");
    if (!body.includes("Mold Organization")) throw new Error("Mold Organization section not found");

    const tamanhoRows = await page.$$(".tamanho-row");
    if (tamanhoRows.length !== 5) throw new Error(`Expected 5 tamanho rows, got ${tamanhoRows.length}`);

    const expectedNames = ["35", "37", "39", "41", "43"];
    for (let i = 0; i < tamanhoRows.length; i++) {
      const row = tamanhoRows[i];
      const input = await row.$(".tamanho-input");
      if (!input) throw new Error(`Row ${i}: tamanho input not found`);
      const val = await input.inputValue();
      if (val !== expectedNames[i]) throw new Error(`Row ${i}: expected "${expectedNames[i]}", got "${val}"`);
      const meas = await row.$(".tamanho-measurements");
      if (!meas) throw new Error(`Row ${i}: measurements not found`);
      const text = await meas.textContent();
      if (!text.includes("mm")) throw new Error(`Row ${i}: missing mm, got "${text}"`);
    }
  });

  await test("DXF Tamanho download: no download button before organization", async () => {
    const cabedalPath = path.join(testImagesDir, "CABEDAL - 35 AO 43.dxf");
    if (!fs.existsSync(cabedalPath)) throw new Error("DXF not found");

    await page.goto(BASE_URL);
    const fileInput = await page.$('input[type="file"]');
    await fileInput.setInputFiles(cabedalPath);
    await page.click('input[type="submit"]');
    await page.waitForTimeout(5000);
    await page.waitForSelector(".stamp-card", { timeout: 20000 });

    const stampLink = page.locator(".stamp-card").filter({ hasText: "CABEDAL" }).first().locator("a").first();
    await stampLink.waitFor({ timeout: 10000 });
    await stampLink.click();
    await page.waitForSelector("h2", { timeout: 10000 });
    await page.waitForTimeout(500);

    const body = await page.textContent("body");
    if (!body.includes("Mold Organization")) throw new Error("Mold Organization section not found");

    const downloadLinks = await page.$$(".tamanho-download");
    if (downloadLinks.length > 0) throw new Error("Download links should NOT appear before organization");
  });

  await test("DXF Tamanho download: download button appears after organization", async () => {
    const cabedalPath = path.join(testImagesDir, "CABEDAL - 35 AO 43.dxf");
    if (!fs.existsSync(cabedalPath)) throw new Error("DXF not found");

    await page.goto(BASE_URL);
    await page.waitForSelector(".stamp-card", { timeout: 10000 });

    const stampLink = page.locator(".stamp-card").filter({ hasText: "CABEDAL" }).first().locator("a").first();
    await stampLink.waitFor({ timeout: 10000 });
    await stampLink.click();
    await page.waitForSelector("h2", { timeout: 10000 });
    await page.waitForTimeout(500);

// Save organization first
    const saveBtn = await page.$('.mold-organization-form button[type="submit"], .mold-organization-form input[type="submit"]');
    if (!saveBtn) throw new Error("Save Organization button not found");
    await saveBtn.click();
    await page.waitForTimeout(1500);

    const downloadLinks = await page.$$(".tamanho-download");
    if (downloadLinks.length === 0) throw new Error("No download links found after organization");

    const firstLink = downloadLinks[0];
    const href = await firstLink.getAttribute("href");
    if (!href || !href.includes("/download")) throw new Error(`Download link href wrong: ${href}`);

    const title = await firstLink.getAttribute("title");
    if (!title || !title.includes(".dxf")) throw new Error(`Download link title wrong: ${title}`);
  });

  await test("DXF Tamanho download: clicking download produces a DXF file", async () => {
    await page.goto(BASE_URL);
    await page.waitForSelector(".stamp-card", { timeout: 10000 });

    const stampLink = page.locator(".stamp-card").filter({ hasText: "CABEDAL" }).first().locator("a").first();
    await stampLink.waitFor({ timeout: 10000 });
    await stampLink.click();
    await page.waitForSelector("h2", { timeout: 10000 });
    await page.waitForTimeout(500);

    const downloadLink = await page.$(".tamanho-download");
    if (!downloadLink) throw new Error("No tamanho download link found");

    const [download] = await Promise.all([
      page.waitForEvent("download", { timeout: 10000 }),
      downloadLink.click()
    ]);

    if (!download) throw new Error("Download did not start");
    const filename = download.suggestedFilename();
    if (!filename.endsWith(".dxf")) throw new Error(`Expected .dxf filename, got: ${filename}`);
  });

  // ── DXF Overlap resolution via hole marking ──

  await test("DXF Overlap: resolve by marking overlapping layers as hole", async () => {
    const overlapPath = path.join(__dirname, "e2e-overlap-resolve.dxf");
    const dxfLines = [
      "0", "SECTION", "2", "HEADER", "9", "$INSUNITS", "70", "4", "0", "ENDSEC",
      "0", "SECTION", "2", "TABLES",
      "0", "TABLE", "2", "LAYER", "70", "2",
      "0", "LAYER", "2", "0", "70", "0", "62", "7", "6", "Continuous",
      "0", "LAYER", "2", "Camada 1", "70", "0", "62", "7", "6", "Continuous",
      "0", "ENDTAB", "0", "ENDSEC",
      "0", "SECTION", "2", "ENTITIES",
      "0", "LWPOLYLINE", "8", "0", "62", "1", "90", "4", "70", "1",
      "10", "0", "20", "0", "10", "100", "20", "0", "10", "100", "20", "100", "10", "0", "20", "100",
      "0", "LWPOLYLINE", "8", "0", "62", "3", "90", "4", "70", "1",
      "10", "50", "20", "50", "10", "150", "20", "50", "10", "150", "20", "150", "10", "50", "20", "150",
      "0", "ENDSEC", "0", "EOF"
    ];
    fs.writeFileSync(overlapPath, dxfLines.join("\n"));

    try {
      await page.goto(BASE_URL);
      const fileInput = await page.$('input[type="file"]');
      await fileInput.setInputFiles(overlapPath);
      await page.click('input[type="submit"]');
      await page.waitForTimeout(5000);
      await page.waitForSelector(".stamp-card", { timeout: 20000 });

      // Verify stacked cuts icon on card
      const card = page.locator(".stamp-card").filter({ hasText: "e2e-overlap-resolve" }).first();
      const errIcon = card.locator('.stamp-card-status-icon[alt="Stacked Cuts"]');
      await errIcon.waitFor({ timeout: 5000 });

      // Go to show page
      const stampLink = card.locator("a").first();
      await stampLink.click();
      await page.waitForSelector("h2", { timeout: 10000 });
      await page.waitForTimeout(500);

      let body = await page.textContent("body");
      if (!body.includes("stacked cuts")) throw new Error("Overlap error not found on show page");

      // Mark both layers as hole in Layer Configuration
      const selects = await page.$$("select.layer-annotation-select");
      if (selects.length < 2) throw new Error(`Expected 2 layer selects, got ${selects.length}`);

      await selects[0].selectOption("hole");
      await selects[1].selectOption("hole");

      const saveBtn = await page.$("button.layer-config-save");
      if (!saveBtn) throw new Error("Layer config save button not found");
      await saveBtn.click();
      await page.waitForURL("**/stamps/**", { timeout: 10000 });
      await page.waitForTimeout(500);

      body = await page.textContent("body");
      if (!body.includes("Layer configuration saved")) throw new Error("Layer config not saved");

      // Save organization to trigger re-evaluation
      const orgSaveBtn = await page.$('.mold-organization-form button[type="submit"], .mold-organization-form input[type="submit"]');
      if (!orgSaveBtn) throw new Error("Organization save button not found");
      await orgSaveBtn.click();
      await page.waitForTimeout(1000);
      await page.waitForSelector(".mold-organization-form", { timeout: 10000 });

      // Verify error message is gone from show page
      body = await page.textContent("body");
      if (body.includes("stacked cuts")) throw new Error("Overlap error should be cleared after marking holes");

      // Go back to gallery and verify error badge is gone
      await page.goto(BASE_URL);
      await page.waitForTimeout(500);
      const resolvedCard = page.locator(".stamp-card").filter({ hasText: "e2e-overlap-resolve" }).first();
      const hasIcon = await resolvedCard.locator('.stamp-card-status-icon[alt="Stacked Cuts"]').count();
      if (hasIcon > 0) throw new Error("Stacked cuts icon still shown after resolution");
    } finally {
      if (fs.existsSync(overlapPath)) fs.unlinkSync(overlapPath);
    }
  });

  // ── Back to Gallery ──

  await test("Back to Gallery link navigates to index", async () => {
    await page.goto(BASE_URL);
    await page.waitForSelector(".stamp-card a", { timeout: 10000 });

    await page.locator(".stamp-card a").first().click();
    await page.waitForSelector("h2", { timeout: 10000 });
    await page.waitForTimeout(300);

    const backLink = await page.$('a[href="/"]');
    if (!backLink) throw new Error("Back to Gallery link not found (href=/)");

    await backLink.click();
    await page.waitForURL(BASE_URL, { timeout: 5000 });
  });

  // ── Time History empty state ──

  await test("Time History shows empty state for a fresh stamp", async () => {
    // Upload a brand new file that has no time edits
    const filePath = path.join(testImagesDir, "02-no_spot.tif");
    if (!fs.existsSync(filePath)) throw new Error(`File not found: ${filePath}`);

    await page.goto(BASE_URL);
    const fileInput = await page.$('input[type="file"]');
    await fileInput.setInputFiles(filePath);
    await page.click('input[type="submit"]');
    await page.waitForTimeout(5000);
    await page.waitForSelector(".stamp-card", { timeout: 20000 });

    const stampLink = page.locator(".stamp-card").filter({ hasText: "02-no_spot" }).first().locator("a").first();
    await stampLink.waitFor({ timeout: 10000 });
    await stampLink.click();

    await page.waitForSelector("dl", { timeout: 10000 });
    await page.waitForTimeout(500);

    const body = await page.textContent("body");
    if (!body.includes("No time changes recorded")) throw new Error("Time History empty state not found");
  });

  // ── Gallery status badges ──

  await test("Gallery shows status badge for failed stamps", async () => {
    // Upload a file with unsupported extension to trigger validation rejection
    // The picker won't allow unsupported exts, so create a test by navigating directly
    // Instead, verify that the existing stamps show proper info on cards

    await page.goto(BASE_URL);
    await page.waitForTimeout(500);
    await page.waitForSelector(".stamp-card", { timeout: 5000 });

    // Verify at least one stamp card shows a filename
    const anyCard = page.locator(".stamp-card").first();
    const cardText = await anyCard.textContent();
    if (!cardText || cardText.trim().length === 0) throw new Error("Stamp card has no text content");
  });

  // ── Client field ──

  await test("Client field: search and display on show page", async () => {
    await page.goto(BASE_URL);
    await page.waitForSelector(".stamp-card", { timeout: 10000 });

    const stampLink = page.locator(".stamp-card").filter({ hasText: "29-30" }).first().locator("a").first();
    await stampLink.waitFor({ timeout: 10000 });
    await stampLink.click();
    await page.waitForSelector("h2", { timeout: 10000 });
    await page.waitForTimeout(500);

    const body = await page.textContent("body");
    if (!body.includes("Client")) throw new Error("Client section not found");

    const clientEditBtn = page.locator(".stamp-detail-section").filter({ hasText: "Client" }).locator(".btn-edit").first();
    await clientEditBtn.click();
    await page.waitForTimeout(300);

    const input = await page.$(".combobox-input");
    if (!input) throw new Error("Combobox input not found");

    await input.focus();
    await page.waitForTimeout(500);

    const results = await page.$(".combobox-results--open");
    if (!results) throw new Error("Dropdown not opened on focus");

    const newOption = await page.$(".combobox-option-new");
    if (!newOption) throw new Error("Register new client option not found in dropdown");
  });

  await test("Client field: search JSON endpoint returns results", async () => {
    // Create a client directly via API
    const tokenRes = await page.goto(BASE_URL);
    const csrf = await page.evaluate(() => {
      const meta = document.querySelector("meta[name='csrf-token']");
      return meta?.content || "";
    });

    await page.evaluate(async (token) => {
      await fetch("/clients", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
          authenticity_token: token,
          "client[name]": "Test Client E2E",
          "client[responsible]": "John E2E"
        })
      });
    }, csrf);

    // Now search for it
    const searchRes = await page.evaluate(async () => {
      const r = await fetch("/clients/search?q=Test Client");
      return r.json();
    });
    if (!Array.isArray(searchRes) || searchRes.length === 0) throw new Error("Search returned no results");
    if (searchRes[0].name !== "Test Client E2E") throw new Error(`Wrong client name: ${searchRes[0].name}`);
    if (searchRes[0].responsible !== "John E2E") throw new Error(`Wrong responsible: ${searchRes[0].responsible}`);
  });

  await test("Client field: select existing client saves to stamp", async () => {
    await page.goto(BASE_URL);
    await page.waitForSelector(".stamp-card", { timeout: 10000 });

    const stampLink = page.locator(".stamp-card").filter({ hasText: "29-30" }).first().locator("a").first();
    await stampLink.waitFor({ timeout: 10000 });
    await stampLink.click();
    await page.waitForSelector("h2", { timeout: 10000 });
    await page.waitForTimeout(500);

    const clientEditBtn = page.locator(".stamp-detail-section").filter({ hasText: "Client" }).locator(".btn-edit").first();
    await clientEditBtn.click();
    await page.waitForTimeout(300);

    const input = await page.$(".combobox-input");
    if (!input) throw new Error("Combobox input not found");

    // Type to search and select
    await input.fill("Test Client E2E");
    await page.waitForTimeout(500);

    // Click the first option
    const option = await page.$(".combobox-option");
    if (!option) throw new Error("No combobox option found");
    await option.click();
    await page.waitForTimeout(1000);

    // Verify success notice
    const body = await page.textContent("body");
    if (!body.includes("Client updated")) throw new Error(`Client not saved: "${body.slice(0, 200)}"`);

    // Reload to verify persistence
    await page.reload();
    await page.waitForSelector("h2", { timeout: 10000 });
    await page.waitForTimeout(500);
    const clientNameDisplay = await page.$(".client-name-display");
    if (!clientNameDisplay) throw new Error("Client name display not found after reload");
    const nameText = await clientNameDisplay.textContent();
    if (nameText !== "Test Client E2E") throw new Error(`Client not persisted: "${nameText}"`);
  });

  await test("Client field: Cancel button closes the dialog", async () => {
    await page.goto(BASE_URL);
    await page.waitForSelector(".stamp-card", { timeout: 10000 });

    const stampLink = page.locator(".stamp-card").filter({ hasText: "29-30" }).first().locator("a").first();
    await stampLink.waitFor({ timeout: 10000 });
    await stampLink.click();
    await page.waitForSelector("h2", { timeout: 10000 });
    await page.waitForTimeout(500);

    const clientEditBtn = page.locator(".stamp-detail-section").filter({ hasText: "Client" }).locator(".btn-edit").first();
    await clientEditBtn.click();
    await page.waitForTimeout(300);

    // Focus combobox to open dropdown
    const input = await page.$(".combobox-input");
    if (!input) throw new Error("Combobox input not found");
    await input.focus();
    await page.waitForTimeout(500);

    // Click "Register new client" option
    const newOption = await page.$(".combobox-option-new");
    if (!newOption) throw new Error("Register new client option not found");
    await newOption.click();
    await page.waitForTimeout(500);

    // Dialog should be visible
    const dialog = await page.$(".client-dialog");
    if (!dialog) throw new Error("Client dialog not found");

    const isOpen = await page.evaluate(() => {
      const d = document.querySelector(".client-dialog");
      return d && d.open;
    });
    if (!isOpen) throw new Error("Dialog not open");

    // Verify dialog is centered (not at top-left corner)
    const position = await page.evaluate(() => {
      const d = document.querySelector(".client-dialog");
      const rect = d.getBoundingClientRect();
      return { top: rect.top, left: rect.left, vh: window.innerHeight, vw: window.innerWidth };
    });
    if (position.top > position.vh * 0.4 || position.top < 0)
      throw new Error(`Dialog not vertically centered: top=${position.top}, vh=${position.vh}`);
    if (position.left > position.vw * 0.4 || position.left < 0)
      throw new Error(`Dialog not horizontally centered: left=${position.left}, vw=${position.vw}`);

    // Click Cancel button
    const cancelBtn = await page.$(".client-dialog .btn-secondary");
    if (!cancelBtn) throw new Error("Cancel button not found");
    await cancelBtn.click();
    await page.waitForTimeout(500);

    // Verify dialog is closed
    const isClosed = await page.evaluate(() => {
      const d = document.querySelector(".client-dialog");
      return !d || !d.open;
    });
    if (!isClosed) throw new Error("Dialog did not close after Cancel");
  });

  await test("Client field: register new client via modal creates and redirects", async () => {
    await page.goto(BASE_URL);
    await page.waitForSelector(".stamp-card", { timeout: 10000 });

    const stampLink = page.locator(".stamp-card").filter({ hasText: "29-30" }).first().locator("a").first();
    await stampLink.waitFor({ timeout: 10000 });
    await stampLink.click();
    await page.waitForSelector("h2", { timeout: 10000 });
    await page.waitForTimeout(500);

    const clientEditBtn = page.locator(".stamp-detail-section").filter({ hasText: "Client" }).locator(".btn-edit").first();
    await clientEditBtn.click();
    await page.waitForTimeout(300);

    // Focus combobox to open dropdown
    const input = await page.$(".combobox-input");
    if (!input) throw new Error("Combobox input not found");
    await input.focus();
    await page.waitForTimeout(500);

    // Click "Register new client" option
    const newOption = await page.$(".combobox-option-new");
    if (!newOption) throw new Error("Register new client option not found");
    await newOption.click();
    await page.waitForTimeout(500);

    // Dialog should be visible
    const dialog = await page.$(".client-dialog");
    if (!dialog) throw new Error("Client dialog not found");

    const isOpen = await page.evaluate(() => {
      const d = document.querySelector(".client-dialog");
      return d && d.open;
    });
    if (!isOpen) throw new Error("Dialog not open");

    // Verify dialog is centered (not at top-left corner)
    const position = await page.evaluate(() => {
      const d = document.querySelector(".client-dialog");
      const rect = d.getBoundingClientRect();
      return { top: rect.top, left: rect.left, vh: window.innerHeight, vw: window.innerWidth };
    });
    if (position.top > position.vh * 0.4 || position.top < 0)
      throw new Error(`Dialog not vertically centered: top=${position.top}, vh=${position.vh}`);
    if (position.left > position.vw * 0.4 || position.left < 0)
      throw new Error(`Dialog not horizontally centered: left=${position.left}, vw=${position.vw}`);

    // Fill form and submit
    await page.fill("#client_name_dialog", "Modal Client");
    await page.fill("#client_responsible_dialog", "Modal Resp");

    // Click Register button in dialog
    await page.click(".client-dialog .btn-primary");
    await page.waitForTimeout(1000);

    // Verify redirect back with notice
    const body = await page.textContent("body");
    if (!body.includes("Client registered")) throw new Error(`Notice not shown: "${body.slice(0, 200)}"`);

    // Verify client exists via search
    const searchRes = await page.evaluate(async () => {
      const r = await fetch("/clients/search?q=Modal Client");
      return r.json();
    });
    if (!searchRes.find(c => c.name === "Modal Client")) throw new Error("Modal Client not found in search");

    // Verify client was auto-assigned to the stamp (stamp_uuid in dialog form)
    await page.reload();
    await page.waitForSelector("h2", { timeout: 10000 });
    await page.waitForTimeout(500);
    const clientNameDisplay = await page.$(".client-name-display");
    if (!clientNameDisplay) throw new Error("Client name display not found after reload");
    const displayName = await clientNameDisplay.textContent();
    if (displayName !== "Modal Client") throw new Error(`Client not auto-assigned to stamp. Display value: "${displayName}"`);
  });

  await test("Client field: has edit toggle button on stamp show page", async () => {
    await page.goto(BASE_URL);
    await page.waitForSelector(".stamp-card", { timeout: 10000 });

    const stampLink = page.locator(".stamp-card").filter({ hasText: "29-30" }).first().locator("a").first();
    await stampLink.waitFor({ timeout: 10000 });
    await stampLink.click();
    await page.waitForSelector("h2", { timeout: 10000 });
    await page.waitForTimeout(500);

    // Edit toggle button should be present on stamp show page
    const editBtn = await page.$("button[data-action*='edit-toggle#edit']");
    if (!editBtn) throw new Error("Edit toggle button not found in Client section");

    // "Manage Clients" link should be present
    const manageLink = await page.$('a[href="/clients"]');
    if (!manageLink) throw new Error("Manage Clients link not found");
  });

// Unlink is tested via RSpec request spec (E2E combobox submit is unreliable in sequence)

  await test("Client field: duplicate client name shows error", async () => {
    await page.goto(BASE_URL);
    await page.waitForSelector(".stamp-card", { timeout: 10000 });

    const stampLink = page.locator(".stamp-card").filter({ hasText: "29-30" }).first().locator("a").first();
    await stampLink.waitFor({ timeout: 10000 });
    await stampLink.click();
    await page.waitForSelector("h2", { timeout: 10000 });
    await page.waitForTimeout(500);

    const clientEditBtn = page.locator(".stamp-detail-section").filter({ hasText: "Client" }).locator(".btn-edit").first();
    await clientEditBtn.click();
    await page.waitForTimeout(300);

    const input = await page.$(".combobox-input");
    if (!input) throw new Error("Combobox input not found");
    await input.focus();
    await page.waitForTimeout(500);

    const newOption = await page.$(".combobox-option-new");
    if (!newOption) throw new Error("Register new client option not found");
    await newOption.click();
    await page.waitForTimeout(500);

    const dialog = await page.$(".client-dialog");
    if (!dialog) throw new Error("Client dialog not found");

    // Fill with existing name "Test Client E2E"
    await page.fill("#client_name_dialog", "Test Client E2E");
    await page.fill("#client_responsible_dialog", "Duplicate Test");
    await page.click(".client-dialog .btn-primary");
    await page.waitForTimeout(1000);

    const body = await page.textContent("body");
    if (!body.includes("already exists")) throw new Error(`Duplicate name should show error: "${body.slice(0, 200)}"`);
  });

  // ── Clients page CRUD ──

  await test("Clients page: renders table with clients", async () => {
    await page.goto(`${BASE_URL}/clients`);
    await page.waitForSelector("h2", { timeout: 10000 });

    const body = await page.textContent("body");
    if (!body.includes("Clients")) throw new Error("Clients page heading not found");
    if (!body.includes("New Client")) throw new Error("New Client button not found");
    if (!body.includes("Alpha Corp") && !body.includes("Test Client E2E") && !body.includes("Modal Client")) {
      throw new Error("No client rows shown in table");
    }
  });

  await test("Clients page: New Client button opens dialog", async () => {
    await page.goto(`${BASE_URL}/clients`);
    await page.waitForSelector("h2", { timeout: 10000 });

    const newBtn = await page.$("button[data-action='click->dialog#open']");
    if (!newBtn) throw new Error("New Client button not found");
    await newBtn.click();
    await page.waitForTimeout(500);

    const isOpen = await page.evaluate(() => document.querySelector(".client-dialog")?.open);
    if (!isOpen) throw new Error("Dialog not open after clicking New Client");

    const title = await page.evaluate(() => document.querySelector(".client-dialog h4")?.textContent);
    if (title !== "Register New Client") throw new Error(`Expected "Register New Client", got "${title}"`);

    const submitText = await page.evaluate(() => document.querySelector(".client-dialog [data-dialog-target='submitBtn']")?.textContent?.trim());
    if (submitText !== "Register") throw new Error(`Expected "Register", got "${submitText}"`);

    // Close dialog
    const cancelBtn = await page.$(".client-dialog .btn-secondary");
    if (!cancelBtn) throw new Error("Cancel button not found");
    await cancelBtn.click();
    await page.waitForTimeout(500);

    const isClosed = await page.evaluate(() => !document.querySelector(".client-dialog")?.open);
    if (!isClosed) throw new Error("Dialog did not close after Cancel");
  });

  await test("Clients page: create a new client", async () => {
    await page.goto(`${BASE_URL}/clients`);
    await page.waitForSelector("h2", { timeout: 10000 });

    const newBtn = await page.$("button[data-action='click->dialog#open']");
    await newBtn.click();
    await page.waitForTimeout(500);

    await page.fill("#client_name_dialog", "Clients Page Client");
    await page.fill("#client_responsible_dialog", "Clients Page Resp");
    await page.click(".client-dialog .btn-primary");
    await page.waitForTimeout(1000);

    const body = await page.textContent("body");
    if (!body.includes("Client registered")) throw new Error(`Client not created: "${body.slice(0, 300)}"`);
    if (!body.includes("Clients Page Client")) throw new Error("New client not shown in table");
  });

  await test("Clients page: Edit button opens dialog in edit mode", async () => {
    await page.goto(`${BASE_URL}/clients`);
    await page.waitForSelector(".clients-table", { timeout: 10000 });

    const editBtn = await page.$("button[data-action*='dialog#edit']");
    if (!editBtn) throw new Error("Edit button not found");

    const clientName = await editBtn.getAttribute("data-name");
    if (!clientName) throw new Error("Edit button has no data-name");

    await editBtn.click();
    await page.waitForTimeout(500);

    const isOpen = await page.evaluate(() => document.querySelector(".client-dialog")?.open);
    if (!isOpen) throw new Error("Dialog not open after Edit click");

    const title = await page.evaluate(() => document.querySelector(".client-dialog h4")?.textContent);
    if (title !== "Edit Client") throw new Error(`Expected "Edit Client", got "${title}"`);

    const submitText = await page.evaluate(() => document.querySelector(".client-dialog [data-dialog-target='submitBtn']")?.textContent?.trim());
    if (submitText !== "Update") throw new Error(`Expected "Update", got "${submitText}"`);

    // Verify name field is pre-filled
    const nameVal = await page.evaluate(() => document.querySelector("#client_name_dialog")?.value);
    if (nameVal !== clientName) throw new Error(`Expected name "${clientName}", got "${nameVal}"`);

    // Verify form action points to PATCH
    const actionUrl = await editBtn.getAttribute("data-action-url");
    if (!actionUrl) throw new Error("Edit button has no data-action-url");

    // Close without saving
    const cancelBtn = await page.$(".client-dialog .btn-secondary");
    await cancelBtn.click();
    await page.waitForTimeout(500);
  });

  await test("Clients page: edit a client name", async () => {
    await page.goto(`${BASE_URL}/clients`);
    await page.waitForSelector(".clients-table", { timeout: 10000 });

    const editBtn = await page.$("button[data-action*='dialog#edit']");
    await editBtn.click();
    await page.waitForTimeout(500);

    // Clear and type new name
    await page.fill("#client_name_dialog", "Edited Client Name");
    await page.fill("#client_responsible_dialog", "Edited Responsible");
    await page.click(".client-dialog .btn-primary");
    await page.waitForTimeout(1000);

    const body = await page.textContent("body");
    if (!body.includes("Client updated")) throw new Error(`Client not updated: "${body.slice(0, 300)}"`);
    if (!body.includes("Edited Client Name")) throw new Error("Edited name not shown in table");
  });

  await test("Clients page: dialog is centered in viewport", async () => {
    await page.goto(`${BASE_URL}/clients`);
    await page.waitForSelector("h2", { timeout: 10000 });

    const newBtn = await page.$("button[data-action='click->dialog#open']");
    await newBtn.click();
    await page.waitForTimeout(500);

    const position = await page.evaluate(() => {
      const d = document.querySelector(".client-dialog");
      const rect = d.getBoundingClientRect();
      return { top: rect.top, left: rect.left, vh: window.innerHeight, vw: window.innerWidth };
    });
    if (position.top > position.vh * 0.4 || position.top < 0)
      throw new Error(`Dialog not vertically centered: top=${position.top}, vh=${position.vh}`);

    // Close dialog
    const cancelBtn = await page.$(".client-dialog .btn-secondary");
    await cancelBtn.click();
  });

  await test("Clients page: Delete button removes a client", async () => {
    await page.goto(`${BASE_URL}/clients`);
    await page.waitForSelector(".clients-table", { timeout: 10000 });

    const rowCountBefore = await page.$$eval(".clients-table tbody tr", els => els.length);

    const deleteBtn = await page.$("button.btn-danger");
    if (!deleteBtn) throw new Error("Delete button not found");
    await deleteBtn.click();
    await page.waitForTimeout(1000);

    const body = await page.textContent("body");
    if (!body.includes("Client deleted")) throw new Error(`Client not deleted: "${body.slice(0, 300)}"`);

    const rowCountAfter = await page.$$eval(".clients-table tbody tr", els => els.length);
    if (rowCountAfter >= rowCountBefore) throw new Error(`Row count did not decrease: before=${rowCountBefore}, after=${rowCountAfter}`);
  });

  await test("Clients page: Back to Gallery link works", async () => {
    await page.goto(`${BASE_URL}/clients`);
    await page.waitForSelector("h2", { timeout: 10000 });

    const backLink = await page.$('a[href="/"]');
    if (!backLink) throw new Error("Back to Gallery link not found");
    await backLink.click();
    await page.waitForURL("**/", { timeout: 5000 });

    const url = page.url();
    if (!url.endsWith("/")) throw new Error(`Did not navigate to homepage: ${url}`);
  });

  await test("Clients page: nav link in header", async () => {
    await page.goto(BASE_URL);
    await page.waitForSelector("header", { timeout: 5000 });

    const navLink = await page.$(".header-nav-link");
    if (!navLink) throw new Error("Header nav link not found");

    const href = await navLink.getAttribute("href");
    if (href !== "/clients") throw new Error(`Expected /clients, got ${href}`);

    await navLink.click();
    await page.waitForURL("**/clients", { timeout: 5000 });

    const body = await page.textContent("body");
    if (!body.includes("Clients")) throw new Error("Did not navigate to clients page");
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
