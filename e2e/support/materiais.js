// A material for specs that need one (an Oxford in white, entered as a
// client's stock): moved from pedidos.spec.js when the cor lisa spec needed
// it too (Etapa 2.5b). Does nothing when an Oxford already exists.
//
// Usage: await ensureMaterialExists(page, BASE_URL)
async function ensureMaterialExists(page, BASE_URL) {
  const res = await page.evaluate(async () => {
    const r = await fetch("/materiais/search?q=Oxford", {
      headers: { "Accept": "application/json" }
    });
    return await r.json();
  });

  if (res.length === 0) {
    await page.goto(`${BASE_URL}/materiais/new`);
    await page.waitForTimeout(500);
    const token = await page.evaluate(() => document.querySelector("meta[name='csrf-token']")?.content || "");

    await page.evaluate(async (csrf) => {
      async function findOrCreate(kind, nome) {
        const searchUrl = kind === "grupo" ? `/materiais/grupos?q=${encodeURIComponent(nome)}` : "/materiais/cores";
        const found = await (await fetch(searchUrl, { headers: { Accept: "application/json" } })).json();
        const existing = found.find((r) => r.nome === nome);
        if (existing) return existing.id;

        const form = new FormData();
        form.append(`${kind === "grupo" ? "grupo_material" : "cor_material"}[nome]`, nome);
        await fetch(`/materiais/create_${kind}`, { method: "POST", headers: { "X-CSRF-Token": csrf }, body: form, redirect: "manual" });
        const created = await (await fetch(searchUrl, { headers: { Accept: "application/json" } })).json();
        return created.find((r) => r.nome === nome)?.id;
      }

      const grupoId = await findOrCreate("grupo", "Oxford");
      const corId = await findOrCreate("cor", "Branco");

      const clientName = "E2E Pedidos Material Setup";
      await fetch("/clients", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded", "X-CSRF-Token": csrf },
        body: new URLSearchParams({ "client[name]": clientName, "client[responsible]": "Tester" })
      });
      const clients = await (await fetch(`/clients/search?q=${encodeURIComponent(clientName)}`)).json();
      const clientId = clients.find((c) => c.name === clientName)?.id;

      const form = new FormData();
      form.append("movimento_estoque[client_uuid]", clientId);
      form.append("movimento_estoque[tipo]", "entrada");
      form.append("movimento_estoque[grupo_material_uuid]", grupoId);
      form.append("movimento_estoque[cor_material_uuid]", corId);
      form.append("movimento_estoque[largura]", "1.40");
      form.append("movimento_estoque[gramatura]", "100g");
      form.append("movimento_estoque[quantidade]", "50");
      form.append("movimento_estoque[valor]", "");
      await fetch("/materiais", {
        method: "POST",
        headers: { "X-CSRF-Token": csrf },
        body: form,
        redirect: "manual"
      });
    }, token);
  }
}

module.exports = { ensureMaterialExists };
