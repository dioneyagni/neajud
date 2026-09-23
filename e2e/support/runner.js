// Shared harness for e2e/*.spec.js: one browser page per spec file, tests run
// sequentially and a failure never aborts the rest, and a "Results:" line that
// bin/e2e output (and CI logs) are read by.

const { chromium } = require("playwright");

const BASE_URL = "http://localhost:3000";
const HEADED = process.argv.includes("--headed") || process.argv.includes("-h");

async function openPage() {
  const launchOpts = { slowMo: HEADED ? 300 : 0 };
  if (HEADED) {
    launchOpts.headless = false;
    launchOpts.args = ["--start-maximized"];
  }
  const browser = await chromium.launch(launchOpts);
  const context = await browser.newContext(HEADED ? { viewport: null } : {});
  const page = await context.newPage();
  return { browser, page };
}

// Collects console errors for the summary; echoes batch-select debug lines.
function watchConsole(page) {
  const consoleErrors = [];
  page.on("console", (msg) => {
    if (msg.type() === "error") consoleErrors.push(msg.text());
    if (msg.text().includes("[batch-select]")) console.log(`  [BROWSER] ${msg.text()}`);
  });
  page.on("pageerror", (err) => consoleErrors.push(`PAGE ERROR: ${err.message}`));
  page.on("dialog", async (dialog) => {
    await dialog.accept();
  });
  return consoleErrors;
}

function makeTest(counts) {
  return async function test(name, fn) {
    try {
      await fn();
      console.log(`  PASS  ${name}`);
      counts.passed++;
    } catch (err) {
      console.log(`  FAIL  ${name}`);
      console.error(`        ${err.message}`);
      counts.failed++;
    }
  };
}

function printSummary(counts, consoleErrors) {
  const total = counts.passed + counts.failed;
  console.log(`\nResults: ${counts.passed} passed, ${counts.failed} failed, ${total} total\n`);
  if (consoleErrors.length === 0) return;
  console.log("Console errors:");
  for (const err of [...new Set(consoleErrors)].slice(0, 10)) console.log(`  ${err}`);
  console.log("");
}

// Usage: runSpec("Arquivos E2E: upload", async ({ page, test }) => { await test("…", async () => {…}); });
function runSpec(title, body) {
  (async () => {
    const { browser, page } = await openPage();
    const consoleErrors = watchConsole(page);
    const counts = { passed: 0, failed: 0 };
    console.log(`\n${title}\n`);
    await body({ page, test: makeTest(counts) });
    printSummary(counts, consoleErrors);
    await browser.close();
    process.exit(counts.failed > 0 ? 1 : 0);
  })().catch((err) => {
    console.error("Fatal:", err);
    process.exit(1);
  });
}

module.exports = { BASE_URL, HEADED, runSpec };
