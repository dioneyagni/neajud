# Estoque e materiais

Stock in meters, owners, the default paper (Etapa 2.3). Moved out of `AGENTS.md` on 19/10/2026; read it when working on this area.

## Stock and materials (Etapa 2.3)

Decided 09/10/2026, kept by hand for now: stock in **linear meters**
(`metros` helper). `MateriaPrima#tipo` is tecido, papel or filme (the dublagem's ligante), with
`preco_metro` (the sale price; a movement's `valor` is the cost, per meter).
A movement without client is the **empresa's own stock** — the form marks
it ("Owner: Empresa", `MovimentoEstoque#da_empresa`), so a forgotten client
never turns into the empresa's by accident. `SaldosDeEstoque` splits each
material's balance by owner for the Materials page (type and price edited
there, `PATCH /materiais/:uuid`). The default paper (`Empresa#papel_padrao`,
a papel) gives `Empresa#largura_papel_efetiva_mm` for the artes' meters per
piece, else the typed `largura_papel_mm`. The dublagem and the sale of
fabric come later (docs/plano.md, Etapa 2.3).

## The groups as families (Dublagem 1/5)

Decided 27/10/2026 (docs/plano.md, Etapa 2.9): `GrupoMaterial` acts as a
family, after the PIM pattern of families with required attributes:

- **Roles:** `superficie` (goes on the face) and `base` (dubs another), both
  allowed (TNT). **Printing:** `estampavel` sim / ressalvas / nao, the
  ressalva's text required with "ressalvas" (`ressalva`).
- **Attributes asked:** `atributos`, `{ name => required? }` from the fixed
  list `GrupoMaterial::ATRIBUTOS` (gramatura, densidade, espessura_mm, micras,
  fornecedor; largura always). New and pre-1/5 groups ask a required gramatura,
  as before. Set on the group's page (`GrupoMateriaisController`,
  `/grupos-de-material`, estoque: ver / editar), linked from Materiais as
  "Grupos"; groups are still created in the stock entry's "+ Register new".
- **The material** (`MateriaPrima`) has `densidade`, `espessura_mm`, `micras`
  and `fornecedor`; all of them and the gramatura are in the duplicate rule
  (Espuma 3 mm and 5 mm are two materials). A group that doesn't weigh its
  materials leaves `gramatura` as "" (the column is not null). A required
  attribute is checked **on create only**: a requirement added later marks the
  materials already there (`atributos_faltando`, "falta …" on Materiais) and
  never refuses their edits. `nome_completo` adds densidade, espessura and
  micras after the group and the fornecedor at the end, only when present, so
  the pre-1/5 names didn't change.
- **The stock entry** (`MovimentoCreatable#atributos_do_material`) takes only
  what the group asks — a field it doesn't ask is dropped, so the same
  material is found again — and the form shows the group's fields
  (`/materiais/grupos` sends `atributos`; `atributos-do-grupo` Stimulus
  controller, the required ones marked with `*`).
- **The tecido pedido prints only on what prints:** `MateriaPrima.estampaveis`
  (tecido of a group that isn't "nao") in the item's select, the controllers
  that set it and the card modal's search (`/materiais/search?estampavel=1`);
  an item keeps its own material if its group stopped printing. A group with
  ressalvas shows its text on the item (`aviso_de_ressalva`), never a block.
- The type `filme` is labeled "Ligante (dublagem)"; filme, filme PU and filme
  TPU are groups of it, in micras. The cola waits for Dublagem 5/5 (the stock
  only knows meters).
- E2E: `e2e/grupos-de-material.spec.js`.

## Where a pedido's materials come from (Etapa 2.3d1)

Decided 19/10/2026:

- **Whose fabric cascades cliente → molde → pedido** (`dono_tecido` on
  `clients`, `moldes`, `pedidos`; blank = inherit, nothing set = "cliente";
  `EscolheDonoDoTecido` validates it). `DonoDoTecido` is the only place that
  resolves it: `do_item(item)` (a calçado item reads its file's molde, like
  its price; a tecido item has no molde), `do_pedido(pedido)`, `herdado(pedido)`
  (what a blank pedido inherits, nil when its moldes differ). Confirming
  writes each item's (`itens_pedido.dono_tecido`, `Pedido#gravar_dono_do_tecido!`;
  a split copies it), and a written item no longer follows the levels. The
  tecido's fabric is charged when its item's owner is the empresa
  (`PrecosDoItemTecido#cobra_tecido?`).
- Chosen on the client's page (`client[dono_tecido]`, clientes: editar), the
  molde's (`molde[dono_tecido]`, catálogo: editar) and the pedido's panel
  (`pedidos/_materiais_do_pedido`, every type but DTF), each blank option
  saying what it inherits and from where (`MateriaisDoPedidoHelper`).
- **What a pedido prints on** (`MaterialDeImpressaoDoPedido`):
  `pedidos.material_impressao_id`, blank = the empresa's default — the
  `papel_padrao` (calçado, tecido) or the **`filme_dtf_padrao`** (DTF; the
  material type `filme_dtf`, separate from the dublagem's `filme`, whose width
  replaces the typed `largura_filme_dtf_mm` — `Empresa#largura_filme_dtf_efetiva_mm`
  — and redoes every fit). A paper of any width (`Pedido#largura_do_papel_mm`
  feeds the Impressão's expected meters and the tecido's width warning); a
  film only of the default's width, since each size's fit is stored for it.
- `MateriaisDoPedidoController` (`PATCH /pedidos/:uuid/materiais`, while the
  draft is editable): the owner by whoever edits it (the cliente final knows
  whether he brings the fabric), the paper or film by the team. A reposição
  copies both from its pedido.
- E2E: `e2e/materiais-do-pedido.spec.js`.


## The stock out at confirmation and "aguardando material" (Etapa 2.3d2)

Decided 19/10/2026 (20/10: nothing backfilled — pedidos confirmed before
this stage took nothing from the stock, and won't):

- **`SaidaDoPedido`** runs when a pedido is confirmed
  (`ConfirmacaoDoPedido`, the concern holding `PedidosController#confirmar`;
  each pedido of a calçado split) and when a reposição is released
  (`LiberarReposicaoService`). One `saida` movement per material × owner, with
  `movimento_estoques.pedido_id`, from the production lines' expected meters:
  calçado — the Corte's fabric, summed per item owner
  (`ProducaoPedidoService.call(pedido, itens:)`, `DonoDoTecido.do_item`; a
  reposição's pieces from the item they came from) and the Impressão's paper;
  tecido — each item's meters of its fabric and of the paper; DTF — the
  written fit's meters of the film. Paper and film are always the empresa's.
  A line without material or metragem takes nothing and comes back in the
  flash ("No stock out: …"); never a block. Only once per pedido.
- **A trashed pedido's outs don't count** (`MovimentoEstoque.que_contam`,
  used by `SaldosDeEstoque` and `AguardandoMaterial`); restored, they do. The
  ledger (`movimentos/_tabela`, on Materials and Movements) links each out to
  its pedido. Movements are never edited.
- **`AguardandoMaterial`** — computed per request, never stored: per material
  × owner, the outs in creation order (by hand too), the entries covering the
  oldest first; a pedido whose out passes them waits for the difference. A
  delivered pedido counts but doesn't show. Shown on the pedidos list (badge,
  filter `?aguardando=1`), the pedido's panel (`pedidos/_aguardando_material`)
  and under each material on Materials (`AguardandoMaterialHelper`).
- **Visibility:** it reads every movement (the paper is the empresa's even on
  a client's pedido); the helper filters what a cliente final sees — that his
  pedido waits ("Aguardando: material"), and the meters of his own fabric
  only.
- Tests: `spec/services/{saida_do_pedido,aguardando_material}_spec.rb`,
  `spec/requests/saida_do_estoque_spec.rb`, E2E `e2e/saida-do-estoque.spec.js`.

## The stock adjusted by the real (Etapa 2.3e)

Decided 20/10/2026:

- **Which stages take material**: `material:` in `config/etapas_producao.yml`
  (`EtapasProducao::Etapa#ajusta_estoque?`) — `impressao` (the pedido's
  paper or DTF film: Impressão of calçado, tecido and DTF) or `linha` (each
  line's fabric: the calçado's Corte, the tecido's Calandra). Stages counted
  in pieces don't touch the stock.
- **`MateriaisDasLinhas`**: the expected meters per material × owner of a
  baixa's lines. A Corte line may join items of different owners, so the
  Corte's lines are rebuilt per owner (`DonoDoTecido.itens_por_dono`, shared
  with `SaidaDoPedido`); a Calandra line's item says its owner.
- **One measure per material**: a whole-stage baixa whose open lines take
  several materials shows one field each (`pedidos/_baixa`, `materiais:`;
  Stimulus `baixa` sends `medidas[<material uuid>]`). `RegistrarBaixaService`
  refuses a missing one, checks the dono's band per material and keeps them
  in `baixas_producao.medidas` (`BaixaProducao#medida_de`); `medida` is the sum.
- **`AjusteDaBaixa`**, in the baixa's transaction: per material, real −
  expected, split between owners by their expected (by pieces when none; the
  rounding on the last). More: a `saida`; less: an `entrada`; the same:
  nothing. The movement has `pedido_id` and `baixa_producao_id`. **Only a
  material × owner the pedido took at confirmation** (`MovimentoEstoque.da_confirmacao`):
  pedidos confirmed before 2.3d2 are never adjusted.
- **Undoing the baixa** stops its adjustment counting (`que_contam` leaves
  out undone baixas' movements; redone, the new baixa makes its own) — the
  balances and "aguardando material" follow by themselves.
- **Shown** (`AjusteDoEstoqueHelper`): the ledger names the stage ("#8f3a1b2c
  · Calandra") and "baixa desfeita: não conta" (`MovimentoEstoque#motivo_de_nao_contar`);
  the stage's baixa history "estoque: +1,2 m Oxford… (MKS)" or "sem saída do
  estoque"; the pedido's panel each material's out, adjustments and real so
  far (`pedidos/_consumo_do_pedido`) — a cliente final his own fabric only.
- Tests: `spec/services/{ajuste_da_baixa,registrar_baixa_service}_spec.rb`,
  `spec/requests/ajuste_do_estoque_spec.rb`, E2E `e2e/ajuste-do-estoque.spec.js`
  (the calçado's Corte is covered by RSpec only: it needs a DXF's fit).
