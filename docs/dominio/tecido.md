# Tecido (corrida e cor lisa)

The tecido pedido, its prices and its production (Etapa 2.7). Moved out of `AGENTS.md` on 19/10/2026; read it when working on this area.

## The tecido pedido (Etapa 2.7a)

Decided 16/10/2026; 2.7 comes in three PRs (2.7a the pedido, 2.7b the prices
and the minimum meters with its approval, 2.7c the production):

- **Type from the item**: a corrida or a cor lisa goes into a **tecido**
  pedido (`Pedido::TIPO_DA_ARTE`, `Pedido#tecido?`). Its client is the
  pedido's like the DTF's (`Pedido#cliente_do_pedido?`,
  `DO_CLIENTE_DO_PEDIDO`): the team picks it, a catálogo work goes into
  anyone's, confirming never splits (`confirmar_sem_corte`). The shared page
  settings live in `AjustesDoPedidoSemCorte` (`PedidosDtfController`,
  `PedidosTecidoController`), the shared pendências in
  `BloqueiosDoClienteDoPedido` (`:pedido_sem_cliente`,
  `:arte_de_outro_cliente`).
- **An item is an arte on a material**: `itens_pedido.materia_prima_id` (a
  `tecido`), `metros` (one decimal — validated on what was typed, the
  column's scale would round) and `largura_mm` (blank =
  `MateriaPrima#largura_mm`; `ItemPedido#largura_efetiva_mm`); no grade, no
  parts. The same arte on two fabrics is two items. Added from the card or
  the page's search (`BuscaDeObras`: number, name, a cor lisa's family) with
  its meters; a blank material takes the cor lisa's (`Arte#materia_prima`).
- **Whose fabric** (`pedidos.dono_tecido`: cliente / empresa), once for the
  whole pedido (decided in 2.3, 09/10/2026); only the empresa's will be
  charged (2.7b). Since 2.3d1 it cascades from the client (blank = inherit,
  `DonoDoTecido`; `docs/dominio/estoque.md`). Each fabric in the item's select shows that owner's
  balance (`saldo_do_tecido`, information only; never the empresa's to a
  cliente final).
- **The cliente final** changes his draft's fabric, meters and owner; the
  width is the team's (how far the RIP repeats the module) and so is the
  client.
- **Pendências** (`PedidoBloqueiosTecido`): no client, an arte of another
  client, no fabric, 0 m, no width (`:sem_largura`, the factory's). Wider
  than the default paper (`Empresa#largura_papel_efetiva_mm`) is a
  **warning** on the item (`aviso_de_largura`), never a block — the factory
  may have a wider paper.
- Its production stages came in 2.7c (see "The tecido's production").
- E2E: `e2e/pedido-tecido.spec.js`.

## The tecido's prices (Etapa 2.7b)

Decided 17/10/2026:

- **Print per meter**, the same for a corrida and a cor lisa at any width:
  the dono's (`Empresa#preco_impressao_metro_tecido`, Parâmetros "Tecido"),
  else nothing; a client may have his own agreed
  (`Client#preco_impressao_metro_tecido`, his page, `PrecosTecidoDoClienteController`,
  the team's with `ver_valores`). The **fabric** is charged only when the
  pedido's `dono_tecido` is `empresa`, at its material's
  `MateriaPrima#preco_metro`.
- **Per item** (`PrecosDoItemTecido` on `ItemPedido`): the edited price
  (`itens_pedido.preco_impressao_metro` / `preco_tecido_metro`, the team's,
  `PrecosDoPedidoTecidoController`) over the starting one, which stays beside
  to measure the discount; confirming writes both (`*_partida`,
  `ValoresDoPedidoTecido.gravar!` in `confirmar_sem_corte`). A confirmed item
  reads what was written. `ValoresDoPedidoTecido` gives each item's charges,
  the print and fabric summed, the total, the discount and `faltas`.
- **Minimum meters per item** (`Empresa#metragem_minima_tecido`, the dono's
  only; blank = none): below it the item is the pendência
  `:abaixo_do_minimo` — the **client's** (outside `DA_FABRICA`: he sees the
  minimum and may raise his meters) — until someone with the action
  `aprovar_abaixo_do_minimo` (team only, `ACOES_DA_EQUIPE`; no função
  got it by migration) approves it (`MinimoDoTecidoController`,
  `ItemPedido#aprovar_minimo!`). The approval holds while the meters are the
  approved ones (`minimo_aprovado_metros`); who and when stay recorded.
  Charged on the real meters.
- **Without price, no confirming**: `:sem_preco_impressao` (link to
  Parâmetros for the dono) and `:sem_preco_tecido` (link to Materiais), the
  factory's.
- **What each sees**: the team with `ver_valores` edits each item's prices
  (`_precos_do_item_tecido`) and sees "Valores do pedido" (`_valores_tecido`)
  with the discount; a cliente final with "valores" open sees only what he
  pays per meter and the subtotal, and the panel's total.
- E2E: `e2e/precos-tecido.spec.js`.

## The tecido's production (Etapa 2.7c)

Decided 19/10/2026:

- **Stages** (`config/etapas_producao.yml`, `tecido:`): **Impressão** (the
  paper) and **Calandra** (onto the fabric, locked on the line's
  Impressão), both in meters, the item's meters expected (`esperado:
  metros`, the dono's band warns); a baixa per line or for the pedido. No
  Conferência or reposição yet.
- **Lines** (`LinhasDeProducao`, `linhas: tecido`): one per item (arte ×
  fabric), key `<item>/<file>`; an item without fabric, meters or width is
  left out (a draft's pendência). Baixas, undoing, the progress and the
  delivery are the calçado's.
- **Compacted at upload** (Q2, so a pedido finds it ready):
  `ArquivoCompactadoTecido` keeps a copy beside the version
  (`<version>/tecido/compactado.<ext>`), queued (`CompactarArquivoTecidoJob`)
  when a corrida's or cor lisa's version finishes processing or an arte
  becomes one (callbacks on `ArquivoVersion`, `TipoDaArte`); existing files:
  `bin/rails producao:compactar_tecido`. `CompactacaoDeArquivo` wraps the
  tool: **TIFF with `tiffcp -c lzw:2`** (`libtiff-tools`), then
  `BlocoPhotoshopDoTiff` copies the spots' names back (tiffcp alone dropped
  them); other formats, a failure or a result not smaller send the
  original. Specs inject `FakeCompactacaoDeArquivo`. The queue and failure
  marks are `CopiaDaVersao`'s, shared with the DTF's turned copy.
- **One page** for both stages (`ProducaoTecidoController#show`,
  `/pedidos/:uuid/tecido/producao/:etapa`; `caminho_da_etapa` and the
  calçado's pages send a tecido there): fabric, width and meters per line;
  on the Impressão, once confirmed, each item's file for the RIP
  (`ArquivoTecidoParaRip`: `CR-12_FLORAL_12,5m_1400mm.tif`, the meters and
  the width to repeat the module) and "Baixar as artes (.zip)"; a missing
  copy is queued and shows "compactando…" (polling `tecido/compactados`).
  The page and the downloads are `ProducaoSemCorte` (the DTF's controller
  includes it too); the files need `baixar_producao`.
- E2E: `e2e/producao-tecido.spec.js`.
