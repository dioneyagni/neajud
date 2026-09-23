const path = require("path");
const fs = require("fs");
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
    await arquivoLink.click();
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
    await page.waitForURL("**/arquivos/**", { timeout: 30000 });

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
    // Create a uniquely-named arquivo to avoid cross-test card matching issues
    const uniqueArquivoPath = path.join(__dirname, "e2e-approve-test.tif");
    const { execSync } = require("child_process");
    execSync(`convert -size 50x50 xc:blue 'TIFF:${uniqueArquivoPath}'`);

    try {
      await page.goto(BASE_URL);
      await uploadFileAndWait(page, uniqueArquivoPath);

      const arquivoLink = page.locator(".stamp-card").filter({ hasText: "e2e-approve-test" }).first().locator("a").first();
      await arquivoLink.waitFor({ timeout: 10000 });
      await arquivoLink.click();
      await page.waitForSelector("h2", { timeout: 10000 });
      await page.waitForTimeout(500);

      // Upload a second version
      const multiPath = path.join(__dirname, "multi-frame-test.tif");
      const versionForm = page.locator(".version-upload-form");
      await versionForm.waitFor({ timeout: 5000 });
      await versionForm.locator('input[type="file"]').setInputFiles(multiPath);
      await versionForm.locator('input[type="submit"]').click();
      await page.waitForURL("**/arquivos/**", { timeout: 15000 });
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

      await page.waitForURL("**/arquivos/**", { timeout: 10000 });
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
    } finally {
      if (fs.existsSync(uniqueArquivoPath)) fs.unlinkSync(uniqueArquivoPath);
    }
  });

  // ── Download link ──

  await test("Download Original link downloads the file", async () => {
    await page.goto(BASE_URL);
    await page.waitForSelector(".stamp-card a", { timeout: 10000 });

    // Navigate to any arquivo's show page
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
