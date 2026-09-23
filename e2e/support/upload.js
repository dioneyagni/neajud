// Shared upload helpers for the gallery form driven by upload_controller.js.

const UPLOAD_TIMEOUT = 15000;

// Clicks upload and waits until upload_controller.js reports every POST
// finished (the server runs ArquivoProcessingJob inline before responding),
// then reloads the gallery. Waiting for ".stamp-card" or a fixed timeout is not
// enough: the pre-upload gallery already matches, so the next step could
// navigate while the job was still running — "DXF Mold Organization: shows …"
// then saw a 29-30 with no tamanho rows, and a navigation mid-batch aborts the
// remaining fetches.
// Usage: await submitUploadAndWait(page, 2) after selecting two files.
async function submitUploadAndWait(page, expectedCount, timeout = UPLOAD_TIMEOUT * expectedCount) {
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
}

// Usage: await uploadFileAndWait(page, "a.tif") or uploadFileAndWait(page, [dxf, tif])
async function uploadFileAndWait(page, filePaths) {
  const files = [].concat(filePaths);
  await page.setInputFiles('input[type="file"]', files);
  await submitUploadAndWait(page, files.length);
}

module.exports = { UPLOAD_TIMEOUT, submitUploadAndWait, uploadFileAndWait };
