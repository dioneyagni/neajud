// Shared upload helpers for the gallery form driven by upload_controller.js.

const UPLOAD_TIMEOUT = 15000;
// Processing is queued (Solid Queue, Etapa 0.3); allow for a slow PSD/DXF.
const PROCESSING_TIMEOUT = 45000;

// Clicks upload and waits until upload_controller.js reports every POST
// finished, then until each created file (by its uuid) leaves
// "pending"/"processing", and reloads the gallery. Waiting for ".stamp-card"
// or a fixed timeout is not enough: the pre-upload gallery already matches, so the next step
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
  // The files this upload created (upload_controller.js): waiting by name was
  // satisfied by an older namesake card — CI 05/10/2026, "01-no_spot" (TIF,
  // processed) while the new 01-no_spot.psd was still processing.
  const uuids = (await page.$eval('form[data-controller="upload"]', (f) => f.dataset.uploadEnviados || "")).split(" ").filter(Boolean);
  if (uuids.length !== expectedCount) throw new Error(`Expected ${expectedCount} created files, the upload reported ${uuids.length}`);
  // upload_controller.js reloads the gallery 1.5 s after "Upload complete";
  // a page.reload of ours meeting it was aborted (ERR_ABORTED, 05/10/2026).
  // Let that one happen first, then wait, then reload with the final states.
  await page.waitForEvent("load", { timeout: 10000 });
  await waitForUploadedProcessed(page, uuids, names);
  await page.reload();
}

// Polls each created file's processing state until it is final, through
// page.request (same session cookies): the gallery reloads itself 1.5 s after
// an upload, which destroyed a page.evaluate mid-poll; and page.waitForFunction
// takes the Promise of an async check as already truthy.
async function waitForUploadedProcessed(page, uuids, names, timeout = PROCESSING_TIMEOUT) {
  const base = new URL(page.url()).origin;
  const limite = Date.now() + timeout;
  while (Date.now() < limite) {
    const finais = await Promise.all(uuids.map(async (uuid) => (await (await page.request.get(`${base}/arquivos/${uuid}/processamento.json`)).json()).final));
    if (finais.every(Boolean)) return;
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  throw new Error(`Processing did not finish within ${timeout}ms for ${names.join(", ")}`);
}

// Usage: await uploadFileAndWait(page, "a.tif") or uploadFileAndWait(page, [dxf, tif])
async function uploadFileAndWait(page, filePaths) {
  const files = [].concat(filePaths);
  await page.setInputFiles('input[type="file"]', files);
  await submitUploadAndWait(page, files.length);
}

module.exports = { UPLOAD_TIMEOUT, submitUploadAndWait, uploadFileAndWait, waitForUploadedProcessed };
