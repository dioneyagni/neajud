// Materials and construções of the dublagem network for the rede's specs
// (rede-editavel, rede-situacoes): Oxford over Lona with Filme 35 µm, each
// spec with its own gramatura so its names never meet another's. A dublado
// gets into stock through an ordem de dublagem marked done (Dublagem 5a):
// the construção is then in use.
//
// Usage: const dublagem = await prepararDublagem(page, `${U}g`);
//        const espuma = await material(page, cor, await grupo(page, "Espuma"), nome, campos, "tecido", busca);
//        const uuid = await salvarConstrucao(page, dublagem, { lado: "trama", situacao: "" });
//        await colocarEmUso(page, uuid);
const { BASE_URL } = require("./runner");
const { postar, buscarJson } = require("./corrida");
const { waitForText } = require("./wait");

// The groups come from the imported network; the roles and the one field
// they ask as construcoes.spec.js sets them (none given: left as they are).
async function grupo(page, nome, papeis, pede) {
  await postar(page, "/materiais/create_grupo", { "grupo_material[nome]": nome });
  const uuid = (await buscarJson(page, `/materiais/grupos?q=${encodeURIComponent(nome)}`)).find((g) => g.nome === nome).id;
  if (!papeis) return uuid;
  const papel = await postar(page, `/grupos-de-material/${uuid}`, {
    _method: "patch", "grupo_material[superficie]": papeis.superficie ? "1" : "0", "grupo_material[base]": papeis.base ? "1" : "0",
    "grupo_material[estampavel]": "nao", "pede[]": pede, "obrigatorios[]": pede,
  });
  if (!papel) throw new Error(`Couldn't set ${nome}'s roles`);
  return uuid;
}

async function material(page, cor, grupoUuid, nome, campos, tipo, busca) {
  const entrou = await postar(page, "/movimentos", {
    "movimento_estoque[da_empresa]": "true", "movimento_estoque[tipo]": "entrada", "movimento_estoque[quantidade]": "30",
    "movimento_estoque[grupo_material_uuid]": grupoUuid, "movimento_estoque[cor_material_uuid]": cor, "movimento_estoque[largura]": "1.40 m", ...campos,
  });
  if (!entrou) throw new Error(`The entry of ${nome} failed`);
  const encontrado = (await buscarJson(page, `/materiais/search?q=${encodeURIComponent(busca)}`)).find((m) => m.nome_completo === nome);
  if (!encontrado) throw new Error(`${nome} wasn't registered`);
  await postar(page, `/materiais/${encontrado.id}`, { _method: "patch", "materia_prima[tipo]": tipo, "materia_prima[preco_metro]": "1" });
  return encontrado.id;
}

// The materials' uuids and full names.
async function prepararDublagem(page, gramatura) {
  await page.goto(`${BASE_URL}/materiais`);
  let cor = (await buscarJson(page, "/materiais/cores")).find((c) => c.nome === "Branco")?.id;
  if (!cor) {
    await postar(page, "/materiais/create_cor", { "cor_material[nome]": "Branco" });
    cor = (await buscarJson(page, "/materiais/cores")).find((c) => c.nome === "Branco").id;
  }
  const nomes = { oxford: `Oxford-Branco-1.40 m-${gramatura}`, lona: `Lona-Branco-1.40 m-${gramatura}`, filme35: "Filme 35 µm-Branco-1.40 m" };
  const oxford = await grupo(page, "Oxford");
  const lona = await grupo(page, "Lona", { base: true }, "gramatura");
  const filme = await grupo(page, "Filme", {}, "micras");
  const ids = {
    oxford: await material(page, cor, oxford, nomes.oxford, { "movimento_estoque[gramatura]": gramatura }, "tecido", gramatura),
    lona: await material(page, cor, lona, nomes.lona, { "movimento_estoque[gramatura]": gramatura }, "tecido", gramatura),
    filme: await material(page, cor, filme, nomes.filme35, { "movimento_estoque[micras]": "35" }, "filme", "Filme"),
  };
  return { nomes, ids };
}

// Oxford (on the lado) over Lona with Filme 35 µm; the new construção's uuid.
async function salvarConstrucao(page, { ids }, { lado, situacao }) {
  const url = await page.evaluate(async (campos) => {
    const token = document.querySelector('meta[name="csrf-token"]')?.content || "";
    return (await fetch("/construcoes", { method: "POST", body: new URLSearchParams({ authenticity_token: token, ...campos }) })).url;
  }, {
    // Dublagem 5b1a: one card of the chave.
    "construcao[situacao]": situacao, "construcao[client_uuid]": "", "construcao[preco_final]": "30",
    "construcao[dublagens][0][cima][escolha]": ids.oxford, "construcao[dublagens][0][cima][lado]": lado, "construcao[dublagens][0][cima][do_cliente]": "0",
    "construcao[dublagens][0][baixo][escolha]": ids.lona, "construcao[dublagens][0][ligante_uuid]": ids.filme, "construcao[dublagens][0][baixo][do_cliente]": "0",
  });
  const uuid = url.match(/construcoes\/([0-9a-f-]{36})\/edit/)?.[1];
  if (!uuid) throw new Error(`The construção wasn't saved: ${url}`);
  return uuid;
}

async function colocarEmUso(page, construcao) {
  await postar(page, "/dublagens", { construcao_uuid: construcao, metros: "5" });
  await page.goto(`${BASE_URL}/dublagens`);
  await page.locator(`article[data-ordem][data-construcao="${construcao}"] input[type="submit"][value="Marcar feita"]`).click();
  await waitForText(page, "feita: entraram");
}

module.exports = { prepararDublagem, salvarConstrucao, colocarEmUso, grupo, material };
