const { BASE_URL, runSpec } = require("./support/runner");
const { uploadFileAndWait } = require("./support/upload");
const { testImagePath, ensureTestImage } = require("./support/fixtures");

ensureTestImage();

runSpec("Arquivos E2E: gallery view, pagination & batch", async ({ page, test }) => {
  // ── Gallery view toggle & pagination ──

  await test("Gallery defaults to grid view with toggle buttons", async () => {
    await page.goto(BASE_URL);
    const hasGrid = await page.$(".gallery");
    if (!hasGrid) throw new Error("Default view is not grid");
    const toggleGrid = await page.$(".view-toggle-btn--active");
    if (!toggleGrid) throw new Error("No active toggle button");
    const text = await toggleGrid.textContent();
    if (!text.includes("Grid")) throw new Error(`Active toggle is not Grid: "${text}"`);
  });

  await test("Switching to list view shows list layout", async () => {
    await page.goto(BASE_URL);
    await page.click(".view-toggle-btn:has-text('List')");
    await page.waitForURL("**/arquivos?view=list");
    const listView = await page.$(".list-view");
    if (!listView) throw new Error("List view not rendered after toggle");
    const gallery = await page.$(".gallery");
    if (gallery) throw new Error("Grid still rendered after switching to list");
  });

  await test("Switching back to grid view shows grid layout", async () => {
    await page.goto(`${BASE_URL}?view=list`);
    await page.click(".view-toggle-btn:has-text('Grid')");
    await page.waitForURL("**/arquivos?view=grid");
    const gallery = await page.$(".gallery");
    if (!gallery) throw new Error("Grid not rendered after switching back");
    const listView = await page.$(".list-view");
    if (listView) throw new Error("List still rendered after switching to grid");
  });

  await test("Pagination controls appear when many files exist", async () => {
    await page.goto(BASE_URL);
    const pagination = await page.$(".pagination");
    if (!pagination) {
      // Not enough files — upload enough to trigger pagination (12 per page)
      for (let i = 0; i < 14; i++) {
        await uploadFileAndWait(page, testImagePath);
      }
      await page.goto(BASE_URL);
      await page.waitForSelector(".pagination", { timeout: 15000 });
    }
  });

  await test("Pagination next link navigates to page 2", async () => {
    await page.goto(BASE_URL);
    const nextLink = await page.$(".pagination-link:has-text('Next')");
    if (!nextLink) {
      // Upload more files to get pagination if needed
      for (let i = 0; i < 14; i++) {
        await uploadFileAndWait(page, testImagePath);
      }
      await page.goto(BASE_URL);
    }
    await page.waitForSelector(".pagination-link:has-text('Next')", { timeout: 15000 });
    await page.click(".pagination-link:has-text('Next')");
    await page.waitForURL("**/arquivos?page=2*");
    // Verify page 2 content rendered (gallery should exist)
    await page.waitForSelector(".gallery", { timeout: 5000 });
  });

  // ── Batch select & delete ──

  await test("Batch toolbar appears when checkboxes are checked in grid view", async () => {
    await page.goto(BASE_URL);
    // Upload files if none exist
    const cards = await page.$$(".stamp-card-checkbox input");
    if (cards.length < 2) {
      for (let i = 0; i < 3; i++) {
        await uploadFileAndWait(page, testImagePath);
      }
      await page.goto(BASE_URL);
      await page.waitForSelector(".stamp-card", { timeout: 5000 });
    }
    const checkbox = (await page.$$(".stamp-card-checkbox input"))[0];
    const checkboxValue = await checkbox.getAttribute("value");
    if (!checkboxValue) throw new Error("Checkbox has no value");
    await checkbox.check();
    await page.waitForSelector(".batch-toolbar:not(.batch-toolbar--hidden)", { timeout: 3000 });
    const toolbarVisible = await page.$(".batch-toolbar:not(.batch-toolbar--hidden)");
    if (!toolbarVisible) throw new Error("Batch toolbar did not appear after checking checkbox");
    const countText = await page.textContent("[data-batch-select-target='count']");
    if (!countText.includes("1")) throw new Error(`Expected "1 selected", got "${countText}"`);
    // Uncheck — toolbar hides
    await checkbox.uncheck();
    await page.waitForTimeout(300);
    const toolbarHidden = await page.$(".batch-toolbar.batch-toolbar--hidden");
    if (!toolbarHidden) throw new Error("Batch toolbar did not hide after unchecking");
  });

  await test("Select All checks all visible checkboxes in grid view", async () => {
    await page.goto(BASE_URL);
    await page.waitForSelector(".stamp-card", { timeout: 5000 });
    // Ensure we have enough cards visible
    let cardCount = (await page.$$(".stamp-card")).length;
    if (cardCount < 2) {
      for (let i = 0; i < 3; i++) {
        await uploadFileAndWait(page, testImagePath);
      }
      await page.goto(BASE_URL);
      await page.waitForSelector(".stamp-card", { timeout: 5000 });
      cardCount = (await page.$$(".stamp-card")).length;
    }
    const selectAll = page.locator("[data-batch-select-target='selectAll']");
    await selectAll.check();
    const checked = await page.$$eval(".stamp-card-checkbox input:checked", els => els.length);
    if (checked !== cardCount) throw new Error(`Expected ${cardCount} checked, got ${checked}`);
  });

  await test("Batch delete removes selected files", async () => {
    await page.goto(BASE_URL);
    await page.waitForSelector(".stamp-card", { timeout: 5000 });
    // Upload at least 2 files if needed
    let cardCount = (await page.$$(".stamp-card")).length;
    if (cardCount < 2) {
      for (let i = 0; i < 3; i++) {
        await uploadFileAndWait(page, testImagePath);
      }
      await page.goto(BASE_URL);
      await page.waitForSelector(".stamp-card", { timeout: 5000 });
    }
    // Record UUIDs of files to delete
    const checkboxes = await page.$$(".stamp-card-checkbox input");
    const deletedIds = [];
    for (let i = 0; i < Math.min(2, checkboxes.length); i++) {
      deletedIds.push(await checkboxes[i].getAttribute("value"));
    }
    await checkboxes[0].check();
    await checkboxes[1].check();
    await page.waitForSelector(".batch-toolbar:not(.batch-toolbar--hidden)", { timeout: 3000 });
    // Click delete — dialog auto-accepted
    await Promise.all([
      page.waitForNavigation({ waitUntil: "domcontentloaded", timeout: 15000 }),
      page.click("[data-batch-select-target='deleteButton']"),
    ]);
    const currentIds = await page.$$eval(".stamp-card-checkbox input", els => els.map(e => e.value));
    for (const id of deletedIds) {
      if (currentIds.includes(id)) throw new Error(`File ${id} still present after batch delete`);
    }
  });
});
