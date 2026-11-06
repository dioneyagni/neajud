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

**The insumos say the stage that uses them up** (decided 28/10/2026): papel
"Papel (impressão)", filme_dtf "Filme DTF (impressão)", **kraft** "Kraft
(calandra)" and **plastico_succao** "Plástico de sucção (corte)". A fabric is
only chosen among `MateriaPrima.tecidos`: the calçado item's material (the
`?tipo=tecido` search and `PedidosController#material_do_item`), the cor
lisa's (`TipoDaArte#material_e_tecido`; one set before keeps showing) and the
tecido item's (`estampaveis`). Taking kraft and plástico out of the stock at
the Calandra and Corte baixas is a later decision.

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
- The development database gets these groups (Oxford, Microfibra, Cetim,
  Telinha, TNT, Helanca, Lona, EVA, Espuma, the three filmes and Papel) and a
  few materials each, with no stock and no price, from `bin/rails dev:semear`
  (`db/seeds/desenvolvimento.rb`, 28/10/2026); it only adds what is missing.

## The dublagem network (Dublagem 2/5)

Decided 29/10/2026 (plano Etapa 2.9, D2/D3/D8). `config/dublagens.yml` says
which groups dub with which: one ligação per pair of `GrupoMaterial` names,
**in any order** (Oxford–Lona is also Lona under Oxford), with its usual
ligantes (a group, with `micras: [25, 35]`, `{ min: 35 }` or any), `dubla:
antes | depois` da estampa, an optional `lado` (only when the rule changes
with the upper layer's side) and `situacoes`, whose ligantes **replace** the
usual ones in that situação (a subset restricts, others change; a situação
not listed keeps the usual ones). The situações' names are fixed at the top.
`a_confirmar` marks what was guessed when it was written.

- `RedeDeDublagens` reads it once and raises on a wrong value, naming the
  ligação and what was expected. A group **not registered is a warning**,
  never an error (`avisos`: not registered, neither superfície nor base, no
  base in the pair), so the test database and a new instance still boot.
- `ligacao(a, b, lado:)`, `ligantes_na(situacao)`, `ligacoes_de(grupo)` and
  `Ligante#serve?(material)` are what the construção (3/5) uses.
- The page **Rede de dublagens** (`/rede-de-dublagens`, linked from Grupos)
  is read only, estoque: ver and **the team's only** (`exige_equipe`): the
  ligante is the factory's. A panel to edit it comes after real use.
- E2E: `e2e/rede-de-dublagens.spec.js`.

## The construção (Dublagem 3/5)

Decided 30/10–02/11/2026 (plano Etapa 2.9, D6/D7). A `Construcao` is a saved
dublado: its `CamadaConstrucao` rows, top to bottom — position 1 the
superfície with its `lado` (trama | avesso), then the bases —, each
`do_cliente` or the empresa's, each base with the `ligante` (a material) that
joins it to the layer above; the `situacao` (one of the network's, blank =
normal) and the `preco_final`. 2 to 5 layers.

- **Its own material** (decision 1): saving it creates or updates a
  `MateriaPrima` of tipo **dublado** — the superfície's group and color, the
  **narrowest layer's width** (decision 3), `preco_metro` = the final price,
  named after the construção ("Oxford Preto (avesso) / Espuma TC4 3 mm
  Branco-1.40 m (Tecido molha)"). The duplicate rule of materials (and its
  unique index) leaves dublados out; a dublado's type never changes and
  nothing else becomes one; on Materiais its row is read only, with a link to
  the construção, and a PATCH of its price is refused. The stock entry never
  finds a dublado by group, color and width. The name **never carries the
  client's**: every client reads the list of materials (`COMUNS`).
- **Whose** (decision 2): a construção may have a client; a layer marked as
  his needs him, and a client needs a layer of his. With a client, the
  construção and its dublado are his (the dublado goes to his stock, 5/5).
- **The rules** (`RegrasDaConstrucao`, a validation): all layers are tecidos;
  the first a superfície, the others bases; each pair a ligação of the
  network (the superfície's lado first); the ligante one the network allows
  in the situação (`OpcoesDaConstrucao#ligantes`) — **or none while no
  registered material serves** (decision 4: the cola until 5/5, shown as
  "a escolher na 5/5"); never the same construção twice (a twin in the trash
  says to restore it).
- **In use** (decision 5): once the dublado has a stock movement or a pedido
  item (`MateriaPrima#em_uso?`) — or, since 4/5, a pedido item is dubbed
  into the construção (`Construcao#em_uso?`) —, only the final price changes; the page says
  why and greys the layers out.
- **Suggested price** (`PrecoSugeridoDaConstrucao`, D7): the empresa's layers
  at their `preco_metro` (the client's show "do cliente"), each ligante's
  `preco_metro` and the empresa's `preco_servico_dublagem` (Parâmetros,
  "Dublagem") times the ligações. A missing price is a line "sem preço" that
  adds nothing, listed under the total.
- **Pages** (estoque: ver lists, editar builds, excluir trashes; **the team's
  only**, as the rede; since 4/5 a cliente final **reads** the empresa's
  construções and his own — `Visibilidade` `Construcao`, to pick his item's —
  never their layers, `CamadaConstrucao` stays the team's): Construções (`/construcoes`, linked from Materiais) and
  the form of the dublagem canvas. Every change posts the form to
  `POST /construcoes/montar`, which answers it again as a turbo-stream — each
  layer's options, the ligação's chips, the price, what is still wrong —
  without saving (`construcao_controller.js`; only the latest answer is
  drawn). A construção goes to the Lixeira (`Excluivel`), its dublado stays.
- The pedido item dubbed into a construção (4/5): `docs/dominio/tecido.md`,
  "The item's construção".
- The ordens de dublagem, the stock in and out and "aguardando dublagem"
  for the construções dubbed before the estampa: "The ordens de dublagem
  (Dublagem 5a)" below. Not yet: dubbing after the estampa (or in parallel
  with the Impressão) as the pedido's own stage, and the cola's measure (5b).
- E2E: `e2e/construcoes.spec.js`.

## The ordens de dublagem (Dublagem 5a)

Decided 03–04/11/2026 (plano Etapa 2.9 D1/D6/D8; the 5/5 split in two: 5a
dubbing before the estampa, through the stock; 5b the pedido's own stage).

- **Which construções**: `Construcao#dubla_antes?` — every ligação dubs
  before the estampa (`config/dublagens.yml`, whose antes/depois the factory
  confirmed on 04/11/2026). Its dublado is made for the stock and may serve
  several pedidos (decision 5a).
- **At confirmation** (`SaidaDoPedido`): such an item takes **its dublado**
  instead of its superfície, from the construção's owner
  (`ItemPedido#material_da_producao`, `#dono_na_producao`; `ConstrucaoDoItem`).
  The Calandra's line is the dublado too (`LinhasDeProducao`), so the
  baixa's adjustment (`MateriaisDasLinhas`, `AjusteDaBaixa`) follows. An item
  whose construção dubs after the estampa, or partly, still takes the
  superfície (5b); the item says so to the team.
- **Em aberto** (`DublagensEmAberto`, computed, never stored): the
  `AguardandoMaterial` faltas of dublados, per construção and owner (only
  the construção's own), less the meters of the ordens generated, with the
  pedidos that wait.
- **The ordem** (`OrdemDublagem`, `ordens_dublagem`; never deleted, decision
  2a): **generated** with the meters (the falta, or more for the stock), then
  **done** with the real meters or **cancelled** (the stock untouched). Done
  (`marcar_feita!`, one transaction): 1 m a meter of each layer out from its
  owner (`do_cliente` = the construção's client), of each ligante from the
  empresa (`ComponentesDaDublagem`; the same material twice is 2 m), and the
  dublado in from the construção's owner — each movement with
  `movimento_estoques.ordem_dublagem_id`. The loss of each dublagem is for
  later. A construção dubbed after the estampa is refused.
- **A missing component never blocks** (decision 4a): the balance goes
  negative, as a baixa's does; before that, em aberto and the generated
  ordens warn "falta componente: X da empresa, 4 m"
  (`OrdensDublagemHelper#falta_de_componentes`), and a ligação without its
  ligante chosen too.
- **The page** `/dublagens` (`OrdensDublagemController`, linked from
  Materiais and Construções): **the team's only** (`Visibilidade`
  `OrdemDublagem` in `DA_EQUIPE`), seen with estoque ver; generating, marking
  done and cancelling need **`atualizar_producao`** (decision 3a: the
  operator who gives the baixas).
- **"Aguardando: dublagem"** (`AguardandoMaterialHelper`): a dublado missing
  reads "dublagem de <construção> · faltam 4 m" on the pedido's panel, the
  badges of the pedidos lists say "aguardando dublagem" (or "material e
  dublagem"), and the production page's line "aguardando dublagem: 4 m" —
  never a block. A cliente final reads only "Aguardando: dublagem". An ordem
  done brings the dublado in and the pedido stops waiting by itself.
- **The ledger** names the ordem ("Dublagem #8f3a1b2c", linked for the team).
- Machines (4 calandras: 1 de estamparia, 2 de dublagem com filme, 1 de
  dublagem com cola) are not modelled: a stage of their own, later.
- Tests: `spec/models/ordem_dublagem_spec.rb`,
  `spec/services/{componentes_da_dublagem,dublagens_em_aberto}_spec.rb`,
  `spec/requests/ordens_dublagem_spec.rb`, E2E `e2e/dublagens.spec.js`.

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

## The material missing, launched at the baixa or the delivery

Decided 05/11/2026. A pedido that kept "aguardando material" after its
production was done (#f0e495d6: the fabric came in, nobody launched it) led
to this. Whoever gives the baixa knows the material arrived:

- **When:** a stage with `material:` whose lines, adjusted (`AjusteDaBaixa`),
  leave the pedido waiting (`AguardandoMaterial`) for a material × owner
  they take (`MateriaisDasLinhas`). Other materials the pedido waits for
  don't ask. `RegistrarBaixaService` saves the baixa and the adjustment in a
  savepoint, checks, and rolls everything back answering `:falta_material`
  (`faltas`: `EntradaDaFalta::Item`, material, owner, `falta`,
  `minimo`). **No baixa without the entry** (Q2 b).
- **At the delivery too** (decided 05/11/2026, after the first test on dev:
  #d4f30331 was delivered skipping its Calandra, the one stage that took its
  fabric; a delivered pedido stops showing as waiting, and the stock stayed
  short). `EntregarPedidoService`, after the "Entregar assim mesmo" for open
  stages, asks for **every** material the pedido still waits for
  (`EntradaDaFalta.faltas(pedido)`, no `partes`), the same way.
- **How much:** at least `minimo`, what frees the pedido:
  `AguardandoMaterial::Falta#para_liberar`, since the entries cover the
  oldest outs first (by hand or of other pedidos), it can exceed the pedido's
  own falta; more when more came.
- **Who:** someone with Estoque: editar launches it directly; anyone else
  types the email and password of someone who has it (`User.authenticate_by`,
  an active user). The password stays with that one launch: the session is
  still the operator's. Wrong attempts are limited like the sign-in (10 per 3
  minutes, `rate_limit` of `EntradaDaFaltaAutorizada`, only when a password comes).
- **Recorded:** a plain `entrada` with no `pedido_id`: the material is the
  stock's, and a trashed pedido must not take it away. It has
  `lancada_na_baixa_id` or `lancada_na_entrega_id`, `lancado_por_id` and
  `autorizado_por_id` (only when someone else authorized). It points at the
  baixa through `lancada_na_baixa` and not `baixa_producao`, so **undoing the
  baixa keeps the entry** (Q4 a, the material arrived either way). The ledger
  shows "lançada na baixa de #… · Calandra, por X, autorizada por Y" (or
  "lançada na entrega de #…"), without the names for a cliente final.
- **Screen:** `pedidos/_dialogo_da_falta`, driven by
  `controllers/dialogo_da_falta.js` from the `baixa` or the `entrega`
  Stimulus controller. It has one row per material × owner (starting at the
  minimum), the authorizer's fields when `pode_lancar` is false, and "Lançar
  entrada e dar baixa" (or "e entregar") / Cancelar. It sends the request
  again with `entradas[<material uuid>:<client uuid|empresa>]` and
  `autorizador[email|senha]`. The fields, the JSON and the password limit
  are shared by both controllers (`EntradaDaFaltaAutorizada`).
- Tests: `spec/services/entrada_da_falta_spec.rb` (with "at the delivery",
  the regression), `spec/requests/baixas_producao_spec.rb` ("the material
  missing"), E2E `e2e/ajuste-do-estoque.spec.js` (the baixa's dialog, Cancel,
  a Produção worker with the dono's password) and
  `e2e/saida-do-estoque.spec.js` (the delivery's dialog).
