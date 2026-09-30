const { BASE_URL, runSpec } = require("./support/runner");

runSpec("Clients E2E Tests", async ({ page, test }) => {
  const UNIQ = `C${Date.now()}`;


  // Client has no seed data (see AGENTS.md) — provision one via the API so
  // this test still exercises "the page loads and lists a real client",
  // not just the empty state covered elsewhere.
  await test("Clients page loads and lists a registered client", async () => {
    const listName = `List Check ${UNIQ}`;
    await page.goto(BASE_URL);
    const csrf = await page.evaluate(() => document.querySelector('meta[name="csrf-token"]')?.content || "");
    await page.evaluate(async ({ csrf, listName }) => {
      await fetch("/clients", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded", "X-CSRF-Token": csrf },
        body: new URLSearchParams({ "client[name]": listName, "client[responsible]": "Tester" })
      });
    }, { csrf, listName });

    await page.goto(`${BASE_URL}/clients`);
    const body = await page.textContent("body");
    if (!body.includes("Clients")) throw new Error("Page heading not found");
    if (!body.includes(listName)) throw new Error(`Registered client "${listName}" not found`);
  });

  await test("Clients page shows table with Name and Responsible columns", async () => {
    await page.goto(`${BASE_URL}/clients`);
    const table = page.locator(".clients-table");
    await table.waitFor({ timeout: 5000 });
    const headers = await table.locator("th").allTextContents();
    if (!headers.includes("Name")) throw new Error("Name column not found");
    if (!headers.includes("Responsible")) throw new Error("Responsible column not found");
  });

  await test("New Client button opens dialog", async () => {
    await page.goto(`${BASE_URL}/clients`);
    await page.click('button:has-text("New Client")');
    await page.waitForTimeout(300);

    const dialog = page.locator("dialog.client-dialog");
    const isOpen = await dialog.evaluate((el) => el.open);
    if (!isOpen) throw new Error("Dialog did not open");
  });

  await test("Create a new client via dialog", async () => {
    await page.goto(`${BASE_URL}/clients`);
    await page.click('button:has-text("New Client")');
    await page.waitForTimeout(300);

    await page.fill('input[name="client[name]"]', `E2E Corp ${UNIQ}`);
    await page.fill('input[name="client[responsible]"]', `Tester ${UNIQ}`);
    await page.click('button[data-dialog-target="submitBtn"]:has-text("Register")');

    await page.waitForURL("**/clients", { timeout: 10000 });
    await page.waitForTimeout(500);

    const body = await page.textContent("body");
    if (!body.includes(`E2E Corp ${UNIQ}`)) {
      throw new Error(`New client not found in table. Body preview: ${body.slice(0, 300)}`);
    }
  });

  await test("Cancel dialog does not create client", async () => {
    await page.goto(`${BASE_URL}/clients`);
    const countBefore = await page.locator(".clients-table tbody tr").count();

    await page.click('button:has-text("New Client")');
    await page.waitForTimeout(300);

    await page.fill('input[name="client[name]"]', `Should Not Exist ${UNIQ}`);
    await page.fill('input[name="client[responsible]"]', "Nope");

    await page.click('button[data-action="click->dialog#close"]:has-text("Cancel")');
    await page.waitForTimeout(300);

    const countAfter = await page.locator(".clients-table tbody tr").count();
    if (countAfter !== countBefore) {
      throw new Error(`Row count changed from ${countBefore} to ${countAfter} after cancel`);
    }
  });

  await test("Edit client via dialog", async () => {
    await page.goto(`${BASE_URL}/clients`);

    const editBtn = page.locator('button:has-text("Edit")').first();
    await editBtn.click();
    await page.waitForTimeout(300);

    const dialog = page.locator("dialog.client-dialog");
    const isOpen = await dialog.evaluate((el) => el.open);
    if (!isOpen) throw new Error("Edit dialog did not open");

    const title = await page.locator('[data-dialog-target="dialogTitle"]').textContent();
    if (!title.includes("Edit")) throw new Error(`Dialog title not 'Edit', got "${title}"`);

    await page.fill('input[name="client[name]"]', `Edited ${UNIQ}`);
    await page.click('button[data-dialog-target="submitBtn"]:has-text("Update")');
    await page.waitForTimeout(500);

    const body = await page.textContent("body");
    if (!body.includes(`Edited ${UNIQ}`)) {
      throw new Error("Edited client name not found");
    }
  });

  await test("Delete client via button", async () => {
    // Create a temporary client to delete
    await page.goto(`${BASE_URL}/clients`);
    await page.click('button:has-text("New Client")');
    await page.waitForTimeout(300);
    await page.fill('input[name="client[name]"]', `Delete Me ${UNIQ}`);
    await page.fill('input[name="client[responsible]"]', "Temp");
    await page.click('button[data-dialog-target="submitBtn"]:has-text("Register")');
    await page.waitForURL("**/clients", { timeout: 10000 });
    await page.waitForTimeout(500);

    const countBefore = await page.locator(".clients-table tbody tr").count();

    // button_to in Rails 8 renders a <button> inside a <form class="button_to">
    const deleteBtn = page.locator('form.button_to button.btn-danger').first();
    await deleteBtn.click();
    await page.waitForTimeout(1000);

    const countAfter = await page.locator(".clients-table tbody tr").count();
    if (countAfter >= countBefore) {
      throw new Error(`Expected row count to decrease from ${countBefore}, got ${countAfter}`);
    }
  });

  await test("Client show page displays details", async () => {
    await page.goto(`${BASE_URL}/clients`);
    await page.waitForSelector(".clients-table", { timeout: 5000 });

    const clientLink = page.locator(".clients-table td a").first();
    await clientLink.click();
    await page.waitForLoadState("networkidle");

    const body = await page.textContent("body");
    if (!body.includes("Details")) {
      console.log(`        URL: ${page.url()}`);
      console.log(`        Body preview: ${body.slice(0, 300)}`);
      throw new Error("Details section not found");
    }
    if (!body.includes("Moldes")) throw new Error("Moldes section not found");
    if (!body.includes("Materials")) throw new Error("Materials section not found");

    const backLink = await page.$('a[href="/"]');
    if (!backLink) throw new Error("Back to Gallery link not found");
  });

  await test("Client show page has All Clients navigation link", async () => {
    await page.goto(`${BASE_URL}/clients`);
    await page.waitForSelector(".clients-table", { timeout: 5000 });
    const clientLink = page.locator(".clients-table td a").first();
    await clientLink.click();
    await page.waitForLoadState("networkidle");

    const allClientsLink = page.locator('a:has-text("All Clients")');
    const exists = await allClientsLink.count();
    if (exists === 0) {
      console.log(`        URL: ${page.url()}`);
      const body = await page.textContent("body");
      console.log(`        Body preview: ${body.slice(0, 300)}`);
      throw new Error("All Clients link not found on show page");
    }

    await allClientsLink.click();
    await page.waitForURL("**/clients", { timeout: 10000 });
    const body = await page.textContent("body");
    if (!body.includes("Clients")) throw new Error("Did not navigate back to clients page");
  });
});
