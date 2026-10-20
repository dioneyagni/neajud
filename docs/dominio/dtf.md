# DTF

The etiqueta, the pedido, its prices and its production (Etapa 2.6). Moved out of `AGENTS.md` on 19/10/2026; read it when working on this area.

## The DTF etiqueta (Etapa 2.6a)

Decided 13/10/2026; 2.6 comes in three PRs (2.6a the etiqueta and the
parameters, 2.6b the DTF pedido and its fit on the film, 2.6c the charging):

- **Sizes by measure**: a work without corte has no corte to order its sizes
  by, so `Arte#arquivos_por_parte` orders them by the file's area
  (`ArquivoVersion#medidas_mm`, pixels ÷ DPI, never stored), smaller first,
  the label breaking ties, unmeasured last — "P, M, G" on the card and the
  page. The page shows each size's measure (`medida_do_arquivo`, "1,62 ×
  1,70 cm").
- **The film is a width, not a material** (Parâmetros, "DTF film"):
  `Empresa#largura_filme_dtf_mm` (600), `margem_filme_dtf_mm` (15 at each
  edge, `largura_util_filme_dtf_mm` = 570), `espacamento_dtf_mm` (1,5, both
  ways) and `fileiras_extras_dtf` (0, a pedido may change it in 2.6b).
- **The etiqueta's own spacing** (`artes.espacamento_mm`, blank = the
  default; `Arte#espacamento_efetivo_mm`): set on its page
  (`TiposDaArteController#espacamento`, `exige_equipe`); the cliente final
  never sees it.
- E2E: `e2e/etiqueta-dtf.spec.js` (makes its sizes with `convert` at 300 dpi).

## The DTF pedido (Etapa 2.6b1)

Decided 13/10/2026 (2.6b2 adds the stages and the RIP download, 2.6c the
prices):

- **Type from the item**: `Pedido.tipo_para(arte)`; `adicionar_item` sends an
  etiqueta to the client's **DTF** draft (`pedido_de_destino` filters by
  type), an empty draft takes its first item's type (`aceita_tipo?`), a
  pedido page refuses an item of another type. A DTF item has no parts.
- **The fit is stored per size**: `EncaixeDaEtiqueta` writes
  `arquivos.encaixe_dtf` (copies per row and the row's step, standing and
  turned) when the version is processed or changes, the arte's spacing or
  kind changes, or the dono changes the film (callbacks on `ArquivoVersion`,
  `Arquivo`, `Arte`, `Empresa`). Existing files: `bin/rails
  producao:encaixe_dtf`. The arte page shows it (`encaixe_do_arquivo`, the
  way it goes first; the turn and the spacing only for the team).
- **It turns only when marked** (decided 16/10/2026: picking the orientation
  with fewer meters turned too many): `artes.girar_dtf`, one mark for the
  whole etiqueta — "Girar 90° no filme" on its page, the team's
  (`TiposDaArteController#giro`). `Arte#orientacao_dtf` ("em_pe" /
  "girada") is the fit the pedido, the unit price and the RIP's file use;
  changing it redoes the sizes' fit and price. A size that fits only the
  other way is a pendência (`:nao_cabe_em_pe` "marque Girar",
  `:nao_cabe_girada` "desmarque"); a confirmed pedido keeps its fit.
- **The pedido counts rows**: `EncaixeDoPedidoDtf` — each etiqueta × size in
  its own rows, in its etiqueta's orientation (standing unless marked), the
  last row completed, the extra rows (`itens_pedido_grade.fileiras_extras`,
  blank = `pedidos.fileiras_extras`, which starts at the dono's). Confirming
  writes each line's fit into `itens_pedido_grade.encaixe_dtf`; a confirmed
  pedido reads that.
- **The client is the pedido's** (`confirmar_dtf`: never split):
  `PedidosDtfController` sets the delivery (`pedidos.entrega`, rolo /
  cortada), the extra rows (the cliente final too, on his draft) and the
  client (the team's). `adicionar_item` reads the coleção geral
  (`visiveis(Arquivo, colecao_geral: true)`) so a cliente final orders a
  catálogo etiqueta into his own draft; the card's "Pedido" and the search
  (`artes_para_adicionar?tipo=dtf&q=`) never carry a catálogo work's owner.
- **Pendências**: `PedidoBloqueiosDtf` (pedido without client, an etiqueta
  outside the catálogo of another client, quantity 0, a size without file,
  without measure, wider than the film, or fitting only the way not marked).
- Its production stages came in 2.6b2 (see "The DTF's production").
- E2E: `e2e/pedido-dtf.spec.js`.

## The DTF's prices (Etapa 2.6c)

Decided 13-14/10/2026, before 2.6b2 (a pedido confirmed without prices would
need fixing):

- **Dono and client** (`PrecosDoDtf`, on `Empresa` and `Client`):
  `preco_metro_dtf`, `preco_corte_dtf`, `cobranca_dtf` (quantidade / metro),
  `cobrar_excedente_dtf`; a client's blank follows the dono's. Parâmetros, and
  the client's page (`PrecosDtfDoClienteController`, the team's with
  `ver_valores`).
- **The etiqueta's unit price per size**: `PrecoDaEtiqueta` calculates
  `arquivos.preco_unidade_calculado` (price per meter ÷ units per meter,
  rounded up to the cent; the client's price unless a catálogo work, else the
  dono's) with the fit (`EncaixeDaEtiqueta`) in the etiqueta's orientation
  (`Arte#orientacao_dtf`), and again when a price per meter, the file's
  client or the turn mark changes. `preco_unidade_combinado` is typed over
  it (`PrecosDaEtiquetaController`) and stops following.
- **The pedido** (`CobrancaDoPedidoDtf` on `Pedido`, `ValoresDoPedidoDtf`):
  the charging and the excess cascade dono → cliente → pedido; each line's
  unit price: edited (`itens_pedido_grade.preco_unidade`) > agreed >
  calculated with the ordering client's price per meter > calculated; by
  meter, the whole film; cortada, the cut on every printed unit. The team
  edits them (`PrecosDoPedidoDtfController`); confirming writes the starting
  (`*_partida`) and charged prices and the choices. `:sem_preco_dtf` blocks
  confirming. A cliente final with "valores" open sees only what he pays.
- **One table per etiqueta** (decided 14/10/2026): each line's starting
  price, unit price and subtotal sit in the etiqueta's fit table
  (`_item_dtf`, `_precos_da_linha_dtf`), its footer sums the etiqueta;
  "Valores do pedido" (`_valores_dtf`) keeps only the etiquetas summed, the
  film by meter, the cut and the total (`ValoresDoPedidoDtf::Valores#da_linha`,
  `do_item`, `das_etiquetas`, `do_pedido`); the panel shows the total. The
  pedido page computes the fit and the values once and passes them down.
  Under 600px each row is a block (`.pedido-dtf-blocos`, cells labelled by
  `data-rotulo`).
- E2E: `e2e/precos-dtf.spec.js`.

## The DTF's production (Etapa 2.6b2)

Decided 15/10/2026, after the prices (2.6c):

- **Stages** (`config/etapas_producao.yml`, `dtf:`): **Impressão** in meters
  of film (`esperado: filme`, the dono's band warns) and **Corte** in units
  (`unidade: unidades`, expected the units printed, excess included), locked
  on the Impressão, only when the pedido is delivered cut — a stage's
  `quando: { entrega: cortada }`, read by `EtapasProducao.do_tipo(tipo,
  pedido:)` / `etapa(…, pedido:)` (the panel, the nav, the progress, the
  delivery and the baixas pass the pedido). No Conferência or reposição yet.
- **Lines** (`LinhasDeProducao`, `linhas: dtf`): one per etiqueta × size,
  from `EncaixeDoPedidoDtf` (the fit written at confirmation), key
  `<item>/<size>/<file>`, referência = the item; `Linha#encaixe` carries the
  fit. `RegistrarBaixaService`, undoing, the progress and the delivery are
  the calçado's.
- **One page** for both stages (`ProducaoDtfController#show`,
  `/pedidos/:uuid/dtf/producao/:etapa`; `caminho_da_etapa` and the old
  `impressao` / `corte` / `baixar_impressao` send a DTF there). Under 600px
  each size is a block (`.producao-dtf-tabela`, `data-rotulo`).
- **The file for the RIP** (D4, once confirmed — a draft's fit still
  changes): `ArquivoDtfParaRip` names it with the units printed
  (`DTF-4_ENCRUZILHADA DO SUL_P_128un_girada.tif`); a size of an etiqueta
  marked to turn goes turned 90°, a copy beside its version (`ArquivoGiradoDtf`,
  `<version>/dtf/girada.<ext>`) made by `GirarArquivoDtfJob` on confirming or
  when the Impressão page finds it missing ("preparando…", polling
  `dtf/girados`). `GiroDeArquivo` wraps the tools: **TIFF with `tiffcrop -R
  90`** (`libtiff-tools`) — ImageMagick 6 dropped one of two spot channels,
  the white — then `BlocoPhotoshopDoTiff` copies back the Photoshop block
  (tag 34377) holding the spots' names; PNG with ImageMagick; other formats
  go as they are, `_girar-no-RIP`. A failure is marked and never retried.
  Each line has its link (`dtf/arquivo?linha=`) and "Baixar as artes (.zip)"
  zips them all (`dtf/arquivos`); both need `baixar_producao`. Specs inject
  `FakeGiroDeArquivo`. Since 2.7c the page and downloads are the
  `ProducaoSemCorte` concern, shared with the tecido.
- E2E: `e2e/producao-dtf.spec.js`.
