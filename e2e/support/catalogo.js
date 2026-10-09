// Etapa 1.1 (3/5): modelos are the official list (config/catalogo_oficial.yml,
// loaded by bin/e2e after truncating) and parts belong to the molde. Specs
// can no longer register a modelo with its peças: they pick an official one
// and add the parts to their own molde.

// Usage: const tenis = await modeloOficial(page, "Tenis"); // { id: <uuid>, nome, abreviacao }
async function modeloOficial(page, nome) {
  const modelo = await page.evaluate(async (nome) => {
    const lista = await (await fetch(`/modelos/search?q=${encodeURIComponent(nome)}`)).json();
    return lista.find((m) => m.nome === nome) || null;
  }, nome);
  if (!modelo) throw new Error(`Official modelo "${nome}" not found — is config/catalogo_oficial.yml loaded (bin/rails catalogo:sincronizar)?`);
  return modelo;
}

// Adds the peças (uuids) as parts of the molde (uuid), in order.
// Usage: await adicionarPartes(page, moldeUuid, [lateralUuid, linguaUuid]);
async function adicionarPartes(page, moldeUuid, pecaUuids) {
  const falhas = await page.evaluate(async ({ moldeUuid, pecaUuids }) => {
    const token = document.querySelector("meta[name='csrf-token']")?.content || "";
    const erros = [];
    for (const pecaUuid of pecaUuids) {
      const body = new URLSearchParams({ authenticity_token: token, peca_uuid: pecaUuid });
      const r = await fetch(`/moldes/${moldeUuid}/adicionar_parte`, { method: "POST", body });
      if (!r.ok) erros.push(`${pecaUuid}: ${r.status}`);
    }
    return erros;
  }, { moldeUuid, pecaUuids });
  if (falhas.length) throw new Error(`Could not add parts to molde ${moldeUuid}: ${falhas.join(", ")}`);
}

// Etapa 2.4: a pedido is confirmed only when its molde has a price per pair
// for every ordered number. Prices one band (Calçado's whole grade by default).
// Usage: await precificarMolde(page, moldeUuid, { preco: "10" });
async function precificarMolde(page, moldeUuid, { de = "18", ate = "46", preco = "10" } = {}) {
  const status = await page.evaluate(async ({ moldeUuid, de, ate, preco }) => {
    const token = document.querySelector("meta[name='csrf-token']")?.content || "";
    const body = new URLSearchParams({ authenticity_token: token, "faixa[tamanho_inicial]": de, "faixa[tamanho_final]": ate, "faixa[preco_par]": preco });
    const r = await fetch(`/moldes/${moldeUuid}/faixas`, { method: "POST", body });
    // A refused band also lands on the molde page (with an alert): the proof
    // is the band listed there.
    const rotulo = de === ate ? de : `${de}–${ate}`;
    return (await r.text()).includes(`data-faixa="${rotulo}"`) ? null : `HTTP ${r.status}, band not listed`;
  }, { moldeUuid, de, ate, preco });
  if (status) throw new Error(`Could not price molde ${moldeUuid} (${de}–${ate}: ${preco}): ${status}`);
}

module.exports = { modeloOficial, adicionarPartes, precificarMolde };
