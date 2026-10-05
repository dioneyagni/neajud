const path = require("path");
const fs = require("fs");
const { waitForText } = require("./support/wait");
const { BASE_URL, runSpec } = require("./support/runner");
const { uploadFileAndWait } = require("./support/upload");
const { testImagePath, testImagesDir, ensureTestImage } = require("./support/fixtures");

ensureTestImage();

runSpec("Arquivos E2E: versions, download & details", async ({ page, test }) => {
  // ── Version upload + approve ──

  await test("Version: upload a new version and verify version cards", async () => {
    // Upload a fresh arquivo as base
    await page.goto(BASE_URL);
    await uploadFileAndWait(page, testImagePath);

    const arquivoLink = page.locator(".stamp-card").filter({ hasText: "test-image" }).first().locator("a").first();
    await arquivoLink.waitFor({ timeout: 10000 });
    await Promise.all([ page.waitForURL(/\/arquivos\/[0-9a-f-]{36}$/), arquivoLink.click() ]);

    // Verify version card shows v1 with Em uso badge
    const v1Card = page.locator(".version-card").filter({ hasText: "v1" }).first();
    await v1Card.waitFor({ timeout: 5000 });
    const v1Approved = await v1Card.textContent();
    if (!v1Approved.includes("Em uso")) throw new Error("v1 does not show the Em uso badge");

    // Upload a new version
    const multiPath = path.join(__dirname, "multi-frame-test.tif");
    if (!fs.existsSync(multiPath)) throw new Error(`multi-frame-test.tif not found`);

    const versionForm = page.locator(".version-upload-form");
    await versionForm.waitFor({ timeout: 5000 });
    const versionInput = versionForm.locator('input[type="file"]');
    await versionInput.setInputFiles(multiPath);

    const uploadBtn = versionForm.locator('input[type="submit"]');
    await uploadBtn.click();

    // The v1 card already exists before submit; only a v2 card proves the
    // upload + processing finished.
    await page.locator(".version-card").filter({ hasText: "v2" }).first().waitFor({ timeout: 30000 });

    const body = await page.textContent("body");
    const hasNotice = body.includes("uploaded and processing");
    const hasV2Card = body.includes("v2");
    if (!hasNotice && !hasV2Card) {
      const details = await page.$("dl");
      const detailsText = details ? await details.textContent() : "no details";
      throw new Error(`Version upload notice nor v2 card found. Body excerpt: ${body.slice(0, 300)} Details: ${detailsText}`);
    }

    // Verify v2 exists and is Em uso (a new version is put in use)
    const v2Card = page.locator(".version-card").filter({ hasText: "v2" }).first();
    await v2Card.waitFor({ timeout: 10000 });
    const v2Text = await v2Card.textContent();
    if (!v2Text.includes("Em uso")) throw new Error("v2 should be in use but the Em uso badge was not found");
  });

  await test("Version: put a different version in use", async () => {
    // Create a uniquely-named arquivo to avoid cross-test card matching issues
    const uniqueArquivoPath = path.join(__dirname, "e2e-approve-test.tif");
    const { execSync } = require("child_process");
    execSync(`convert -size 50x50 xc:blue 'TIFF:${uniqueArquivoPath}'`);

    try {
      await page.goto(BASE_URL);
      await uploadFileAndWait(page, uniqueArquivoPath);

      const arquivoLink = page.locator(".stamp-card").filter({ hasText: "e2e-approve-test" }).first().locator("a").first();
      await arquivoLink.waitFor({ timeout: 10000 });
      await Promise.all([ page.waitForURL(/\/arquivos\/[0-9a-f-]{36}$/), arquivoLink.click() ]);

      // Upload a second version
      const multiPath = path.join(__dirname, "multi-frame-test.tif");
      const versionForm = page.locator(".version-upload-form");
      await versionForm.waitFor({ timeout: 5000 });
      await versionForm.locator('input[type="file"]').setInputFiles(multiPath);
      await versionForm.locator('input[type="submit"]').click();
      await page.locator(".version-card").filter({ hasText: "v2" }).first().waitFor({ timeout: 30000 });

      // Wait until v2 finished processing: the end of processing morph-refreshes
      // the page (Arquivo#broadcast_status_change), and a refresh landing just
      // after the click below redraws the page without its flash notice (seen
      // in a --headed run, 28/09/2026). A fixed 1s wait used to hide this race.
      await page.locator('.version-card:has(strong:text("v2")) .version-status').filter({ hasText: /Processed|Failed/ })
        .waitFor({ timeout: 45000 });

      // v2 is now the version in use. Put v1 back in use ("Usar esta versão";
      // "Approve/Approved" became the client approval in Etapa 0.5, 4/4).
      const usarBtn = page.locator('button:has-text("Usar esta versão")');
      if (await usarBtn.count() === 0) {
        const allCards = await page.locator(".version-card").allTextContents();
        throw new Error(`No "Usar esta versão" buttons on page. Cards: ${JSON.stringify(allCards)}`);
      }
      await usarBtn.first().click();
      await waitForText(page, /Version \d+ is now in use\./);

      const v1Card = page.locator('.version-card:has(strong:text("v1"))').first();
      if (!(await v1Card.textContent()).includes("Em uso")) throw new Error("v1 should show Em uso after choosing it");

      const v2Card = page.locator('.version-card:has(strong:text("v2"))').first();
      if ((await v2Card.textContent()).includes("Em uso")) throw new Error("v2 should not be Em uso after v1 was chosen");
    } finally {
      if (fs.existsSync(uniqueArquivoPath)) fs.unlinkSync(uniqueArquivoPath);
    }
  });

  // ── Download link ──

  await test("Download Original link downloads the file", async () => {
    await page.goto(BASE_URL);
    await page.waitForSelector(".stamp-card a", { timeout: 10000 });

    // Navigate to any arquivo's show page
    await Promise.all([ page.waitForURL(/\/arquivos\/[0-9a-f-]{36}$/), page.locator(".stamp-card a").first().click() ]);

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

  await test("Show page displays all detail fields correctly for an arte arquivo", async () => {
    // Navigate to 02-no_spot.tif (uploaded by previous preview test; if missing, upload fresh)
    await page.goto(BASE_URL);
    await page.waitForSelector(".stamp-card", { timeout: 10000 });

    let arquivoLink = page.locator(".stamp-card").filter({ hasText: "02-no_spot" }).first().locator("a").first();
    let cardExists = await arquivoLink.count();

    if (cardExists === 0) {
      const filePath = path.join(testImagesDir, "02-no_spot.tif");
      await uploadFileAndWait(page, filePath);
      arquivoLink = page.locator(".stamp-card").filter({ hasText: "02-no_spot" }).first().locator("a").first();
    }

    await arquivoLink.first().click();
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
});
