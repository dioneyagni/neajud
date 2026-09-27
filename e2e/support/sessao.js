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

module.exports = { E2E_USUARIO, entrar };
