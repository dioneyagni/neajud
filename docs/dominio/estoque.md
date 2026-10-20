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
piece, else the typed `largura_papel_mm`. The consumption at confirmation
and "aguardando material" (2.3d2), the adjustment by the real metragem
(2.3e) and the dublagem come later (docs/plano.md, Etapa 2.3).

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

