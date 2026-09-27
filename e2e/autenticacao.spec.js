// Etapa 0.5 (1/3): first access, sign in and sign out. Must be the FIRST spec
// in bin/e2e's E2E_SPECS: it needs the empty database of a new instance to
// see the setup screen; every later spec then signs in as the dono it creates.
const { E2E_USUARIO } = require("./support/sessao");
const { BASE_URL, runSpec } = require("./support/runner");

runSpec("Autenticação E2E Tests", async ({ page, test }) => {
  async function preencherLogin(email, senha) {
    await page.fill('input[name="email_address"]', email);
    await page.fill('input[name="password"]', senha);
    await page.click('input[type="submit"][value="Sign in"]');
  }

  await test("A new instance sends every page to the first-access setup", async () => {
    await page.goto(`${BASE_URL}/pedidos`);
    await page.waitForURL("**/configuracao");
    if ((await page.locator(".header-nav").count()) !== 0) throw new Error("Navigation shown before anyone signed in");
  });

  await test("Setup creates the company and its owner, already signed in", async () => {
    await page.fill('input[name="configuracao[empresa_nome]"]', E2E_USUARIO.empresa);
    await page.fill('input[name="configuracao[nome]"]', E2E_USUARIO.nome);
    await page.fill('input[name="configuracao[email_address]"]', E2E_USUARIO.email);
    await page.fill('input[name="configuracao[password]"]', E2E_USUARIO.senha);
    await page.click('input[type="submit"][value="Create company and account"]');
    await page.waitForSelector(".header-user");
    const notice = await page.textContent(".flash-notice");
    if (!notice.includes(E2E_USUARIO.nome) || !notice.includes(E2E_USUARIO.empresa)) throw new Error(`Unexpected welcome: "${notice}"`);
    const nome = await page.textContent(".header-user-nome");
    if (nome.trim() !== E2E_USUARIO.nome) throw new Error(`Header shows "${nome}", expected "${E2E_USUARIO.nome}"`);
  });

  await test("Sign out ends the session; pages ask to sign in again", async () => {
    await page.click('.header-user button:has-text("Sign out")');
    await page.waitForURL("**/session/new");
    await page.goto(`${BASE_URL}/pedidos`);
    await page.waitForURL("**/session/new");
  });

  // Once someone exists, the setup screen would let anyone create a second owner.
  await test("The setup screen is closed once the instance is configured", async () => {
    await page.goto(`${BASE_URL}/configuracao`);
    await page.waitForURL("**/session/new");
  });

  await test("A wrong password is refused with a message", async () => {
    await preencherLogin(E2E_USUARIO.email, "senha-errada-123");
    await page.waitForSelector(".alert.flash-notice");
    const alert = await page.textContent(".alert.flash-notice");
    if (!alert.includes("Try another email address or password")) throw new Error(`Unexpected alert: "${alert}"`);
    if ((await page.locator(".header-user").count()) !== 0) throw new Error("Signed in with a wrong password");
  });

  await test("Signing in returns to the page that was asked for", async () => {
    await page.goto(`${BASE_URL}/pedidos`);
    await page.waitForURL("**/session/new");
    await preencherLogin(E2E_USUARIO.email.toUpperCase(), E2E_USUARIO.senha);
    await page.waitForURL(`${BASE_URL}/pedidos`);
    await page.waitForSelector(".header-user");
  });
}, { entrar: false });
