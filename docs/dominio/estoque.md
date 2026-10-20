# Estoque e materiais

Stock in meters, owners, the default paper (Etapa 2.3). Moved out of `AGENTS.md` on 19/10/2026; read it when working on this area.

## Stock and materials (Etapa 2.3)

Decided 09/10/2026, kept by hand for now: stock in **linear meters**
(`metros` helper). `MateriaPrima#tipo` is tecido, papel or filme, with
`preco_metro` (the sale price; a movement's `valor` is the cost, per meter).
A movement without client is the **empresa's own stock** — the form marks
it ("Owner: Empresa", `MovimentoEstoque#da_empresa`), so a forgotten client
never turns into the empresa's by accident. `SaldosDeEstoque` splits each
material's balance by owner for the Materials page (type and price edited
there, `PATCH /materiais/:uuid`). The default paper (`Empresa#papel_padrao`,
a papel) gives `Empresa#largura_papel_efetiva_mm` for the artes' meters per
piece, else the typed `largura_papel_mm`. The adjustment by the real
metragem (2.3e) and the dublagem come later (docs/plano.md, Etapa 2.3).

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
