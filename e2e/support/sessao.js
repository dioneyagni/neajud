// Etapa 0.5: every page needs a signed-in user. The E2E database starts empty
// on each bin/e2e run, so the first spec to sign in goes through the
// first-access setup (/configuracao) and becomes the dono; the others sign in.

const E2E_USUARIO = {
  empresa: "Empresa E2E",
  nome: "Operador E2E",
  email: "e2e@neajud.test",
  senha: "senha-e2e-12345"
};

// Usage: await entrar(page, BASE_URL) — then the page is on the gallery, signed in.
async function entrar(page, baseUrl, usuario = E2E_USUARIO) {
  await page.goto(baseUrl);
  if (page.url().includes("/configuracao")) {
    await page.fill('input[name="configuracao[empresa_nome]"]', usuario.empresa);
    await page.fill('input[name="configuracao[nome]"]', usuario.nome);
    await page.fill('input[name="configuracao[email_address]"]', usuario.email);
    await page.fill('input[name="configuracao[password]"]', usuario.senha);
    await page.click('input[type="submit"][value="Create company and account"]');
  } else if (page.url().includes("/session/new")) {
    await page.fill('input[name="email_address"]', usuario.email);
    await page.fill('input[name="password"]', usuario.senha);
    await page.click('input[type="submit"][value="Sign in"]');
  }
  await page.waitForSelector(".header-user", { timeout: 15000 });
}

// The dono adds a user of the função with a provisional password, signs
// out, and the page signs in as that user, changing the password on the way.
// Usage: await entrarComoNovoUsuario(page, BASE_URL, { nome, email, provisoria, senha }, "Produção")
async function entrarComoNovoUsuario(page, baseUrl, usuario, funcao) {
  await page.goto(`${baseUrl}/usuarios/new`);
  await page.fill('input[name="usuario[nome]"]', usuario.nome);
  await page.fill('input[name="usuario[email_address]"]', usuario.email);
  await page.fill('input[name="usuario[senha_provisoria]"]', usuario.provisoria);
  await page.selectOption('select[name="usuario[funcao_uuid]"]', { label: funcao });
  await page.click('input[type="submit"][value="Add user"]');
  await page.getByText(`${usuario.nome} added`).first().waitFor();
  await page.click('.header-user button:has-text("Sign out")');
  await page.waitForURL("**/session/new");
  await page.fill('input[name="email_address"]', usuario.email);
  await page.fill('input[name="password"]', usuario.provisoria);
  await page.click('input[type="submit"][value="Sign in"]');
  await page.waitForURL("**/senha/edit");
  await page.fill('input[name="nova_senha"]', usuario.senha);
  await page.click('input[type="submit"][value="Change password"]');
  await page.getByText("Password changed.").first().waitFor();
}

module.exports = { E2E_USUARIO, entrar, entrarComoNovoUsuario };
