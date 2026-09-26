// Shared upload helpers for the gallery form driven by upload_controller.js.

const UPLOAD_TIMEOUT = 15000;
// Processing is queued (Solid Queue, Etapa 0.3); allow for a slow PSD/DXF.
const PROCESSING_TIMEOUT = 45000;

// Clicks upload and waits until upload_controller.js reports every POST
// finished, reloads the gallery, then waits until each uploaded file's card
// leaves "pending"/"processing". Waiting for ".stamp-card" or a fixed timeout
// is not enough: the pre-upload gallery already matches, so the next step
// could navigate while the upload (and now the queued job) was still running —
// "DXF Mold Organization: shows …" then saw a 29-30 with no tamanho rows.
// Usage: await submitUploadAndWait(page, 2) after selecting two files.
async function submitUploadAndWait(page, expectedCount, timeout = UPLOAD_TIMEOUT * expectedCount) {
  const names = await page.$eval('input[type="file"]', (input) => Array.from(input.files).map((f) => f.name));
  await page.click('input[type="submit"]');
  await page.waitForFunction(
    () => document.querySelector('input[type="submit"]')?.value.startsWith("Upload complete"),
    null,
    { timeout }
  );
  const status = await page.inputValue('input[type="submit"]');
  const expected = `Upload complete (${expectedCount} ok, 0 failed)`;
  if (status !== expected) throw new Error(`Upload failed: got "${status}", expected "${expected}"`);
  await page.reload();
  await waitForProcessed(page, names);
}

// Waits until the newest gallery card of each file (by name, extension
// ignored) has a final data-status (processed, failed, …). The gallery swaps
// the card by broadcast when the queued job finishes; no reload needed.
// Usage: await waitForProcessed(page, ["e2e-arte.tif"])
async function waitForProcessed(page, fileNames, timeout = PROCESSING_TIMEOUT) {
  const bases = fileNames.map((name) => name.replace(/\.[^.]+$/, ""));
  try {
    await page.waitForFunction((bases) => bases.every((base) => {
      const card = document.querySelector(`.stamp-card[data-filename="${CSS.escape(base)}"]`);
      return card && !["pending", "processing"].includes(card.dataset.status);
    }), bases, { timeout });
  } catch {
    const states = await page.$$eval(".stamp-card", (cards) => cards.slice(0, 10).map((c) => `${c.dataset.filename}=${c.dataset.status}`));
    throw new Error(`Processing did not finish within ${timeout}ms for ${bases.join(", ")}; newest cards: ${states.join(", ")}`);
  }
}

// Usage: await uploadFileAndWait(page, "a.tif") or uploadFileAndWait(page, [dxf, tif])
async function uploadFileAndWait(page, filePaths) {
  const files = [].concat(filePaths);
  await page.setInputFiles('input[type="file"]', files);
  await submitUploadAndWait(page, files.length);
}

module.exports = { UPLOAD_TIMEOUT, submitUploadAndWait, uploadFileAndWait, waitForProcessed };
