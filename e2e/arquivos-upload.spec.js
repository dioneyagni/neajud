const path = require("path");
const { BASE_URL, runSpec } = require("./support/runner");
const { UPLOAD_TIMEOUT, submitUploadAndWait, uploadFileAndWait } = require("./support/upload");
const { testImagePath, ensureTestImage } = require("./support/fixtures");

ensureTestImage();

runSpec("Arquivos E2E: upload & gallery basics", async ({ page, test }) => {
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
    await uploadFileAndWait(page, testImagePath);

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
    await uploadFileAndWait(page, testImagePath);

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
    await uploadFileAndWait(page, testImagePath);

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

  await test("Upload multiple files creates arquivos in gallery", async () => {
    await page.goto(BASE_URL);
    const fileInput = await page.$('input[type="file"]');
    if (!fileInput) throw new Error("File input not found");

    const secondImagePath = path.join(__dirname, "multi-frame-test.tif");
    await fileInput.setInputFiles([testImagePath, secondImagePath]);

    const fileList = await page.$(".upload-file-list");
    const html = await fileList.innerHTML();
    if (!html.includes("test-image")) throw new Error("First file not in list");
    if (!html.includes("multi-frame-test")) throw new Error("Second file not in list");

    await submitUploadAndWait(page, 2);

    const testCard = page.locator(".stamp-card").filter({ hasText: "test-image" }).first();
    const multiCard = page.locator(".stamp-card").filter({ hasText: "multi-frame-test" }).first();
    await testCard.waitFor({ timeout: UPLOAD_TIMEOUT });
    await multiCard.waitFor({ timeout: UPLOAD_TIMEOUT });
  });

  // Etapa 0.3 safety net: with the live connection blocked, no broadcast ever
  // arrives — only the card's own polling ("processamento" controller) can take
  // it from "Na fila"/"Processando" to its final state.
  await test("Without the live connection, a queued card still reaches its final state by polling", async () => {
    const offline = await page.context().newPage();
    await offline.addInitScript(() => {
      window.WebSocket = class { constructor() { throw new Error("WebSocket blocked by the E2E spec"); } };
    });
    try {
      await offline.goto(BASE_URL);
      await uploadFileAndWait(offline, testImagePath);
      const status = await offline.locator('.stamp-card[data-filename="test-image"]').first().getAttribute("data-status");
      if (["pending", "processing"].includes(status)) throw new Error(`Card still ${status}`);
    } finally {
      await offline.close();
    }
  });

  await test("Upload a file creates a arquivo visible in gallery", async () => {
    await page.goto(BASE_URL);
    const fileInput = await page.$('input[type="file"]');
    if (!fileInput) throw new Error("File input not found");

    await fileInput.setInputFiles(testImagePath);

    const fileList = await page.$(".upload-file-list");
    const listHtml = await fileList.innerHTML();
    if (!listHtml.includes("test-image")) throw new Error("File not shown in list after selection");

    await submitUploadAndWait(page, 1);
    const card = page.locator(".stamp-card").filter({ hasText: "test-image" }).first();
    await card.waitFor({ timeout: UPLOAD_TIMEOUT });
  });

  await test("Arquivo show page displays all sections", async () => {
    await page.goto(BASE_URL);
    await uploadFileAndWait(page, testImagePath);
    await page.waitForSelector(".stamp-card a");
    await Promise.all([ page.waitForURL(/\/arquivos\/[0-9a-f-]{36}$/), page.locator(".stamp-card a").first().click() ]);
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
      fd.append("arquivo[original_file]", "");
      if (csrf) fd.append("authenticity_token", csrf);

      const resp = await fetch("/arquivos", {
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

  await test("Edit time updates the arquivo and creates history log", async () => {
    await page.goto(BASE_URL);
    await page.waitForSelector(".stamp-card a");
    await Promise.all([ page.waitForURL(/\/arquivos\/[0-9a-f-]{36}$/), page.click(".stamp-card a") ]);

    await page.click('#update-time-section [data-action="click->edit-toggle#edit"]');
    await page.waitForSelector("#annotated_seconds", { timeout: 5000 });

    await page.fill("#annotated_seconds", "");
    await page.type("#annotated_seconds", "123");
    await page.click(".time-form .btn-confirm");

    await page.waitForTimeout(1500);

    const body = await page.textContent("body");
    if (!body.includes("1:23")) throw new Error("Formatted time 1:23 not found in history");
  });

  await test("Delete arquivo removes it from gallery", async () => {
    await page.goto(BASE_URL);
    await page.waitForSelector(".stamp-card a");

    const firstCardHref = await page.locator(".stamp-card a").first().getAttribute("href");
    await Promise.all([ page.waitForURL(/\/arquivos\/[0-9a-f-]{36}$/), page.locator(".stamp-card a").first().click() ]);

    await page.click('button:has-text("Delete Arquivo")');
    await page.waitForTimeout(2000);

    const body = await page.textContent("body");
    if (!body.includes("Arquivo moved to the trash")) throw new Error("Delete notice not shown");

    const hrefsAfter = await page.$$eval(".stamp-card a", els => els.map(e => e.getAttribute("href")));
    if (hrefsAfter.includes(firstCardHref)) throw new Error("Deleted card link still visible in gallery");
  });

  await test("Gallery shows arquivos or fallback message", async () => {
    await page.goto(BASE_URL);
    await page.waitForTimeout(500);
    const body = await page.textContent("body");
    const hasCard = await page.$(".stamp-card");
    if (hasCard) {
      if (!body.includes("Tracker")) throw new Error("Gallery heading not shown");
    } else {
      if (!body.includes("No arquivos uploaded yet")) throw new Error("Fallback message not shown");
    }
  });
});
