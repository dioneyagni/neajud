# O pedido do calçado

Pedido by arte, grade by number; items made of the arte's parts; price and cost per pair. Moved out of `AGENTS.md` on 19/10/2026; read it when working on this area.

## Pedido by arte, grade by number (Etapa 1.2, 3/3)

Decided 05/10/2026, in three parts; done 07/10/2026 (Fase 1 complete):

- `pedidos.tipo` (`Pedido::TIPOS`: calcado, dtf since Etapa 2.6b1, tecido
  since 2.7a) — one type per pedido, from its items.
- An item is an **arte** (`itens_pedido.arte_id`); `arquivo_id` is the file it
  was added from, still what the pieces below start from until part 2 reads
  them from the arte. Its grade is by **individual size**
  (`Arte#tamanhos_do_pedido`, decided 05/10/2026: the numbers the molde's
  **organized DXF** serve — saved with the grade type, else deduced from the
  size names like the Mold Organization form; without an organized corte,
  the product's whole grade; the molde's stretch doesn't enter; no molde →
  one `_total`), listed first; "+ 23" / "+ 35" add the product's next numbers
  (`Arte#grade_completa_do_pedido`, decided 05/10/2026), and
  `adicionar_item` / `atualizar_item` refuse sizes outside it. In the
  add-to-order modal the grade is a responsive table
  (`grade_por_numero_controller.js`: number over quantity, side by side under
  600px).
- Part 2: where each number comes from and the pendências — see "Pedido
  items are made of the arte's parts".
- Part 3 in three PRs (decided 06/10/2026, layout studied in a Design
  canvas): **3a** the pedido page — two columns, each item a **matrix**
  (`_item_matriz`: a column per number of the product's grade, rows "Pares"
  and one per part with the DXF size ✓ / "sem arquivo"; columns outside the
  DXF's numbers rendered `hidden`, "+ 28" shows them — `grade_matriz_controller.js`;
  a CSS grid that flows by column on wide screens, by row under 600px), and a
  side panel (`_painel`: totals, Confirmar, the pendências with "Enviar
  arquivo" / "Trazer de outra arte", one per part × DXF size). Saving a grade
  or (un)checking a part morph-refreshes the page. **3b** the factory's
  Corte page (`/pedidos/:uuid/corte`, linked from the panel): one line per
  part × DXF size with its drawing (`/tamanhos/:id/preview`, the PNG made with
  the size's DXF, path rebuilt from version + position), the pieces and the
  DXF; "Baixar os DXF (.zip)" (`baixar_corte`, `baixar_producao`) zips every
  size (`ZipDeArquivos`, the rubyzip wrapper; `DxfDoTamanho` extracts a
  size's DXF for both downloads). Pieces = pairs × the molde part's
  `pecas_por_par` (default 2), half right / half left when `espelhada`
  (needs an even number); parts "não corta" are left out (decided
  06/10/2026). Both are edited per part on the molde page (they live in
  `ResolucaoDoItem::Parte#config`). **3c** the printer's Impressão page
  (`/pedidos/:uuid/impressao`, `ImpressaoPedidoService`): per arte, one line
  per file to print (part, DXF size, side) in pieces, "não corta" parts
  included, what is missing as a line; "Baixar as artes (.zip)"
  (`baixar_impressao`) is written to disk (`ZipDeArquivos.gravar`, stored,
  in `tmp/zips/`, cleaned after an hour by `ZipsTemporarios`) — artes go up
  to 1 GB. **Sides** (`arquivos.lado`, `LadoNaArte`: direito / esquerdo):
  a mirrored part may have a file per side; a file without side serves both
  until one with a side arrives in that size, then the other side is a
  pendência `:sem_lado` ("Enviar arquivo DIR"; decided 07/10/2026). Read
  from the name as its own piece, "DIR" / "ESQ" or spelled out
  (`NomeDoArquivo`), chosen in the upload's conference or on the arte page
  (`definir_lado`); in the full name ("…_Lateral_29-30_ESQ") and in "the
  same arte uploaded again" (the other side is never a repeat).
- Added from the gallery card or from the pedido page (molde → referência →
  arte, `pedido_adicionar_controller.js` + `GET /pedidos/artes_para_adicionar`,
  the same `add-to-order` modal with `pedido_uuid`).
- Pedidos from before (grade by the corte's size name) went to the trash in
  the migration, `grade_antiga: true` — read only even restored
  (`Pedido#editavel?`, `recusar_pedido_excluido`).
- E2E: `e2e/pedido-por-arte.spec.js`.

## Pedido items are made of the arte's parts

Adding an arte to a pedido stores one `ItemPedidoPeca` per part of its molde
(e.g. lateral + língua of a tênis), from `MoldeComposicaoService` — the
molde's own parts (`molde_pecas`), each with a file of **that same arte**
(Etapa 1.2, 3/3: never another arte of the molde). A part is `incluida`
(goes to production) or `excluida` (unchecked; the pedido goes without it).

Where each ordered number comes from is `ResolucaoDoItem` (part 2, decided
05/10/2026 — the pedido always reads the arte): per part × number, the size of
the part's organized DXF that serves it (`Tamanho#atende_rotulo?`) and the
arte's production file of that size (`tamanho_id`, else the size read from
its name) — or the part's **piloto** as a sample (only the piloto's size
asked, no production file of it) — or a pendência:

| Pendência | Meaning | Settled by |
|---|---|---|
| `:sem_corte` | no organized DXF of the part serves the number | organizing / linking the DXF |
| `:sem_arquivo` | the DXF serves it, the arte has no file of that size | "Enviar arquivo" (into the arte, part + size filled, back to the pedido) or "Trazer de outra arte" (`/arquivos/:uuid?trazer=1`) |

A file added to the arte settles the pendência in every draft that uses it.
The **parts** themselves follow too (09/10/2026): they were a photo of the
moment the arte was added, so a draft kept a "Sem peça" row (the file, its
part unknown then) next to an empty Cabedal. `ItemPedido#recompor_pecas!`
rebuilds them from `MoldeComposicaoService`, matching rows by peça (an
unchecked part stays unchecked, its uuid kept); `RecomporRascunhos` runs it
on the drafts when a file's part, size, molde or arte changes (`Arquivo`
callbacks) or the molde gains or loses a part (`MoldePeca`). Confirmed
pedidos keep their parts. Existing drafts: `bin/rails pedidos:recompor_rascunhos`.
Confirming is blocked by those pendências of checked parts, an item with total
0, an arte without client (confirming splits the pedido by its artes'
clients) and the item's file in the trash; a grade at total 0 is refused
outright. All blockers come from `PedidoBloqueiosService`
(`Pedido#bloqueios_confirmacao`), which feeds the server guard, the pending
box on the pedido page and the list badge. `Pedido#pecas_para_produzir`
(`ProducaoPedidoService`, built on `ResolucaoDoItem`: lines per part × DXF
size, in pieces, without "não corta" parts) is the **only** place
production reads from.

A draft created for an arte without client has no client: it adopts one
(`Pedido#adotar_cliente_das_artes!`, from `Arquivo`'s `after_update_commit` on
`client_id`) once every arte of it has the same client. An arte without client
gets its molde's client when the molde is chosen (`Arquivo#herdar_cliente_do_molde`).

The old "Escolher arte" / "Enviar arte" per pending piece
(`VincularArteService`, `ArteCandidatasService`) was removed in Etapa 1.2
(3/3, parte 2); the arte page still shows its "Histórico de vínculos".

- E2E coverage: `e2e/pedidos-pecas.spec.js`, `e2e/pedido-por-arte.spec.js`.

## Price and cost per pair (Etapa 2.4, calçado)

Decided 09/10/2026: calçado is charged **per pair**, at the molde's price
for each number — `FaixaDePreco` (table `faixas_de_preco`): bands of the
produto's grade, never overlapping, may go past the molde's stretch
(`Molde#preco_do_par`). Edited on the molde page (`FaixasDePrecoController`,
`/moldes/:uuid/faixas`; catalogo: editar + action `ver_valores`); removing a
band is physical on purpose. Confirming writes each number's price into
`itens_pedido_grade.preco_par` (`Pedido#gravar_precos!`, also copied into the
pedidos a split makes); a number without price — or an arte without molde —
is the `:sem_preco` pendência (link "abrir molde"). The molde is read from
the item's **file** (`item.arquivo.molde`), not `arte.principal`, which skips
a trashed file.

The cost per pair is always estimated now (`CustoPorPar`, on
`ResolucaoDoItem`): each checked part's file × its pieces per pair (a side's
file half) × meters per piece × `Empresa#custo_impressao_metro`, plus pieces
cut × `custo_corte_peca` (Parâmetros); `incompleto` when a file is missing
or has no meters. `CustoPorPar.da_arte` builds an unsaved item to show it on
the arte page before any pedido. `ValoresDoPedido` gives price, cost and
margin per number and in total. A cost marked "*" lists what it misses per
part and reason (`CustoPorPar::Custo#faltas`, `faltas_do_custo` helper,
`pedidos/_faltas_do_custo`). Both blocks render only for
`pode_acao?(:ver_valores)`; a reposição has no values. E2E:
`e2e/precos-do-molde.spec.js`; specs that confirm a pedido price their molde
(`precificarMolde` in `e2e/support/catalogo.js`, `create(:molde, preco: 10)`,
`create(:item_pedido, :com_preco)`).
