// Waits for proof that a form submit finished, instead of waitForURL on a URL
// the page is already on (resolves instantly) plus a fixed timeout. That combo
// made "DXF Overlap: resolve…" flaky when configure_layers took 446ms.

// text: string (case-insensitive substring) or RegExp. Pick text that only
// exists after the submit — not a badge or label already on the page.
// Usage: await saveBtn.click(); await waitForText(page, "Layer configuration saved");
async function waitForText(page, text, timeout = 15000) {
  try {
    await page.getByText(text).first().waitFor({ timeout });
  } catch {
    const body = (await page.textContent("body")) || "";
    throw new Error(`Expected "${text}" within ${timeout}ms; body starts: ${body.replace(/\s+/g, " ").slice(0, 200)}`);
  }
}

module.exports = { waitForText };
