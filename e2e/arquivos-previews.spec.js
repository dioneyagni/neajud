const path = require("path");
const fs = require("fs");
const { BASE_URL, runSpec } = require("./support/runner");
const { UPLOAD_TIMEOUT, uploadFileAndWait } = require("./support/upload");
const { testImagesDir } = require("./support/fixtures");

runSpec("Arquivos E2E: previews, DXF layers & cut type", async ({ page, test }) => {
  // ── 4 preview strategies ──


  async function uploadAndVerify(label, filename, expectedCs, checkPixels = true) {
    await test(`${label}: ${filename} processes and shows preview`, async () => {
      const filePath = path.join(testImagesDir, filename);
      if (!fs.existsSync(filePath)) throw new Error(`Test image not found: ${filePath}`);

      await page.goto(BASE_URL);
      await uploadFileAndWait(page, filePath);

      // Click the arquivo card matching the uploaded filename (without extension)
      const displayName = filename.replace(/\.[^.]+$/, "");
      const arquivoLink = page.locator(".stamp-card").filter({ hasText: displayName }).locator("a").first();
      await arquivoLink.waitFor({ timeout: 10000 });
      await arquivoLink.click();

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
    await uploadFileAndWait(page, filePath);
    const arquivoLink = page.locator(".stamp-card").filter({ hasText: "test.svg" }).locator("a").first();
    await arquivoLink.waitFor({ state: "visible", timeout: UPLOAD_TIMEOUT });
    await arquivoLink.waitFor({ timeout: 10000 });
    await arquivoLink.click();

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
    await uploadFileAndWait(page, dxfPath);

    const arquivoLink = page.locator(".stamp-card").filter({ hasText: "29-30" }).locator("a").first();
    await arquivoLink.waitFor({ timeout: 10000 });
    await arquivoLink.click();
    await page.waitForSelector("dl", { timeout: 10000 });
    await page.waitForTimeout(500);

    const body = (await page.textContent("body")).toLowerCase();
    if (!body.includes("processed")) throw new Error("Status not processed");
    if (!body.includes("corte")) throw new Error("Category not corte");

    // Verify Layer Configuration section exists
    if (!body.includes("layers")) throw new Error("Layer Configuration section not found");

    // Verify layer row in read-only mode: swatch, name, color code, annotation badge
    const layerRow = await page.$('[data-edit-toggle-target="display"] .layer-config-row');
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

    // Verify annotation badge in read-only mode
    const badge = await layerRow.$(".layer-annotation-badge");
    if (!badge) throw new Error("Annotation badge not found");
    const badgeText = (await badge.textContent()).trim().toLowerCase();
    if (badgeText !== "cut") throw new Error(`Expected default annotation "cut", got "${badgeText}"`);

    // Click edit button to enter edit mode and verify select
    await page.keyboard.press("Escape");
    await page.waitForTimeout(300);
    await page.evaluate(() => {
      document.querySelector('button[title="Edit layers"]').click();
    });
    await page.waitForTimeout(500);

    const form = await page.$('form[action*="configure_layers"]');
    if (!form) throw new Error("Layer config form not found");
    const select = await form.$("select.layer-annotation-select");
    if (!select) throw new Error("Annotation select not found in edit mode");
    const selectedValue = await select.inputValue();
    if (selectedValue !== "cut") throw new Error(`Expected default annotation "cut", got "${selectedValue}"`);

    // Verify all 4 annotation options exist
    const optionValues = await select.evaluate(el => Array.from(el.options).map(o => o.value));
    const expectedOptions = ["cut", "hole", "engraving", "ignore"];
    const hasAll = expectedOptions.every(v => optionValues.includes(v));
    if (!hasAll) throw new Error(`Select options missing. Got: ${optionValues.join(",")}`);

    // Cancel to go back to read-only
    await page.evaluate(() => {
      const btn = document.querySelector('[data-edit-toggle-target="form"] .btn-cancel');
      if (btn) btn.click();
    });
  });

  await test("DXF Layer Configuration: change annotation and save", async () => {
    await page.goto(BASE_URL);
    await page.waitForSelector(".stamp-card", { timeout: 10000 });

    const arquivoLink = page.locator(".stamp-card").filter({ hasText: "29-30" }).locator("a").first();
    await arquivoLink.waitFor({ timeout: 10000 });
    await arquivoLink.click();
    await page.waitForSelector("dl", { timeout: 10000 });
    await page.waitForTimeout(500);

    // Verify measurements exist before save
    const beforeMeasure = await page.$('[data-edit-toggle-target="display"] .layer-measurements');
    if (!beforeMeasure) throw new Error("Measurements not found before save");
    const beforeText = await beforeMeasure.textContent();

    // Click edit button to enter edit mode
    await page.keyboard.press("Escape");
    await page.waitForTimeout(300);
    await page.evaluate(() => {
      document.querySelector('button[title="Edit layers"]').click();
    });
    await page.waitForTimeout(500);

    // Change first layer annotation to "hole"
    const form = await page.$('form[action*="configure_layers"]');
    if (!form) throw new Error("Layer config form not found");
    const select = await form.$("select.layer-annotation-select");
    if (!select) throw new Error("Annotation select not found");
    await select.selectOption("hole");

    // Click Save (submit button in form)
    const saveBtn = await form.$('button[type="submit"]');
    if (!saveBtn) throw new Error("Save button not found");
    await saveBtn.click();

    // Wait for redirect back to show page after PATCH
    await page.waitForURL("**/arquivos/**", { timeout: 10000 });
    await page.waitForTimeout(500);

    // Check for success notice
    const body = await page.textContent("body");
    if (!body.includes("Layer configuration saved")) throw new Error("Success notice not shown");

    // Verify annotation persisted in read-only badge
    const badge = await page.$('[data-edit-toggle-target="display"] .layer-annotation-badge');
    if (!badge) throw new Error("Annotation badge not found after save");
    const badgeText = (await badge.textContent()).trim().toLowerCase();
    if (badgeText !== "hole") throw new Error(`Expected "hole" after save, got "${badgeText}"`);

    // Verify measurements still present after save
    const afterMeasure = await page.$('[data-edit-toggle-target="display"] .layer-measurements');
    if (!afterMeasure) throw new Error("Measurements not found after save");
    const afterText = await afterMeasure.textContent();
    if (afterText !== beforeText) throw new Error(`Measurements changed after save. Before: "${beforeText}" After: "${afterText}"`);
  });

  // ── Multi-color DXF with measurements ──

  const reforcoPath = path.join(testImagesDir, "REFORÇO - 35 AO 43.dxf");

  await test("DXF REFORÇO: uploads and shows multiple layers with measurements", async () => {
    if (!fs.existsSync(reforcoPath)) throw new Error(`DXF not found: ${reforcoPath}`);

    await page.goto(BASE_URL);
    await uploadFileAndWait(page, reforcoPath);

    const arquivoLink = page.locator(".stamp-card").filter({ hasText: "REFORÇO" }).locator("a").first();
    await arquivoLink.waitFor({ timeout: 10000 });
    await arquivoLink.click();
    await page.waitForSelector("dl", { timeout: 10000 });
    await page.waitForTimeout(500);

    const bodyText = await page.textContent("body");
    if (!bodyText.toLowerCase().includes("processed")) throw new Error("Status not processed");

    // Verify all 3 layer rows exist in read-only display
    const layerRows = await page.$$('[data-edit-toggle-target="display"] .layer-config-row');
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

  // ── Cut Type (tipo_corte) ──

  await test("Cut Type: section appears on corte DXF arquivos", async () => {
    await page.goto(BASE_URL);
    await page.waitForSelector(".stamp-card", { timeout: 10000 });

    const arquivoLink = page.locator(".stamp-card").filter({ hasText: "29-30" }).first().locator("a").first();
    await arquivoLink.waitFor({ timeout: 10000 });
    await arquivoLink.click();
    await page.waitForSelector("h2", { timeout: 10000 });
    await page.waitForTimeout(500);

    const body = await page.textContent("body");
    if (!body.includes("Cut Type")) throw new Error("Cut Type section not found on corte arquivo");

    // Verify both radio buttons exist
    const corteEstampa = await page.$('input[type="radio"][value="corte_estampa"]');
    if (!corteEstampa) throw new Error("Radio 'corte_estampa' not found");
    const apenasCorte = await page.$('input[type="radio"][value="apenas_corte"]');
    if (!apenasCorte) throw new Error("Radio 'apenas_corte' not found");

    // Default should be corte_estampa
    const isChecked = await corteEstampa.isChecked();
    if (!isChecked) throw new Error("Default tipo_corte should be 'corte_estampa'");

    // Verify the controller is present
    const section = await page.$("#tipo-corte-section [data-controller='tipo-corte']");
    if (!section) throw new Error("tipo-corte Stimulus controller not found");
  });

  await test("Cut Type: section does NOT appear on arte arquivos", async () => {
    const artePath = path.join(__dirname, `e2e-cuttype-arte-${Date.now()}.tif`);
    const { execSync } = require("child_process");
    execSync(`convert -size 20x20 xc:green 'TIFF:${artePath}'`);
    try {
      await page.goto(BASE_URL);
      await uploadFileAndWait(page, artePath);

      const baseName = path.basename(artePath, ".tif");
      const card = page.locator(".stamp-card").filter({ hasText: baseName }).first();
      await card.waitFor({ timeout: 10000 });
      await card.locator("a").first().click();
      await page.waitForSelector("h2", { timeout: 10000 });
      await page.waitForTimeout(500);

      const h3s = await page.$$("h3");
      for (const h3 of h3s) {
        const text = await h3.textContent();
        if (text.includes("Cut Type")) throw new Error("Cut Type section found on arte arquivo");
      }
    } finally {
      if (fs.existsSync(artePath)) fs.unlinkSync(artePath);
    }
  });
});
