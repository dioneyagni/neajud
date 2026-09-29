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

// Waits until a queued task of an arquivo is over (Etapa 0.6), asking the same
// JSON endpoint the page polls — e.g. "/arquivos/<uuid>/preparacao_tamanhos.json".
// An explicit loop: waitForFunction with an async predicate took the pending
// Promise as truthy and returned at once.
// Usage: await waitForQueuedTask(page, `/arquivos/${uuid}/preparacao_tamanhos.json`)
async function waitForQueuedTask(page, jsonPath, timeoutSeconds = 60) {
  const done = await page.evaluate(async ({ jsonPath, timeoutSeconds }) => {
    for (let i = 0; i < timeoutSeconds; i++) {
      const r = await fetch(jsonPath, { headers: { Accept: "application/json" } });
      if ((await r.json()).final) return true;
      await new Promise((resolve) => setTimeout(resolve, 1000));
    }
    return false;
  }, { jsonPath, timeoutSeconds });
  if (!done) throw new Error(`Queued task at ${jsonPath} still running after ${timeoutSeconds}s`);
}

module.exports = { waitForText, waitForQueuedTask };
