# Etapas de produção

Stages, baixas, the cycle and the reposição (Etapa 2.2) — the calçado's; DTF and tecido reuse them. Moved out of `AGENTS.md` on 19/10/2026; read it when working on this area.

## Production stages and expected metragem (Etapa 2.2)

Decided 07/10/2026, in three PRs (docs/plano.md has the full rules): stages
per pedido type in `config/etapas_producao.yml` (calçado: Impressão ∥ Corte →
Estamparia → Conferência, every dependency locks), a granular baixa with the
measure next to each download, warned against an expected value that comes
from the files themselves. Done (1/3 to 4/4):

- **Arte**: `ArquivoVersion#metros_por_peca(largura_mm)` — the file's
  rectangle (pixels ÷ DPI) on the paper's width, its width across the roll —
  a calçado arte **never turns** (`girar:` is for DTF later); plain
  arithmetic, nothing stored. The paper's width is the dono's parameter
  (`Empresa#largura_papel_mm`, `/parametros`, with the warning band
  `tolerancia_abaixo_pct` / `tolerancia_acima_pct`).
- **DXF**: `bin/encaixe-dxf.js` fits copies of one size's outer contour on a
  roll (the DXF's **vertical axis runs along the roll**) on a 2 mm grid —
  about 70% of the fabric, between the pieces' area and their bounding
  boxes. The turn is the corte's "Giro no encaixe" (`arquivos.giro`,
  `GiroNoEncaixe`, set on the corte page, decided 08/10/2026): `nenhum`,
  `180` or `90` (0°/90°/180°/270°), **no default** — whoever uploads the corte
  marks it (it isn't always the same; some TNS/BT laterals go with the long
  side along the roll); until then nothing is computed and the card shows
  "giro não marcado". Changing it redoes the sizes.
  `--svg out.svg` draws the fit to check it by eye. The length is the
  average reach of the strips used (a leftover edge no piece reaches is not
  length). After changing the fit itself: `REFAZER=1 bin/rails
  producao:metros_por_peca`. `EncaixeDoTamanho` stores the result per width in
  `tamanhos.metros_por_peca` (`{ "1400" => 0.0183 }`); `MetrosPorPecaJob`
  computes it after `PreparacaoTamanhosJob` (redoing the size) and when a
  material of a new width is created (`MateriaPrima#largura_mm` reads "1.25 m",
  "140 cm"…). Existing sizes: `bin/rails producao:metros_por_peca`. Specs
  inject `FakeEncaixe`.
- The Corte page's lines are per **material** too (each roll is its own cut);
  `Linha#metros_esperados` there and on the Impressão page.
- **Stages and baixas (2/3)**: `EtapasProducao` reads
  `config/etapas_producao.yml` and raises on a wrong value (medida,
  esperado, linhas, niveis, trava). `LinhasDeProducao` gives each stage's
  lines with **stable keys made of uuids** — Impressão lines (also
  Estamparia's and Conferência's) `item/part/size/file/side` with the
  `corte_chave` they wait for (nil for a part "não corta"); Corte lines
  `part/size/material`. `RegistrarBaixaService` takes a line, a referência
  (the item's uuid) or the whole pedido — only open lines whose locked
  stages are done — sums their expected and answers `:aviso` outside the
  dono's band until `confirmar`, then saves `BaixaProducao` with
  `fora_da_faixa`. Only a **confirmed** pedido takes baixas; the endpoint is
  `POST /pedidos/:uuid/baixas` (JSON, action `atualizar_producao`, given by a
  migration to the existing Admin and Produção funções). Pages: the
  Impressão and Corte pages, plus `/pedidos/:uuid/etapas/:etapa` for
  Estamparia and Conferência; `_etapas_nav`, `_etapa_andamento`,
  `_situacao_baixa`, `_baixa` (Stimulus `baixa`).
- **The cycle (3/3)**: `Pedido::STATUS` rascunho (→ enviado, a client's
  draft waiting for the factory, Etapa 2.8 5/5) → confirmado →
  **em_producao** (`iniciar_producao!` on the first baixa) → **entregue**
  (`EntregarPedidoService`, `POST /pedidos/:uuid/entregar`, Stimulus
  `entrega`: never locked — open stages come back as an aviso, "Entregar
  assim mesmo" delivers; `entregue_em`/`entregue_por`). `Pedido#em_producao?`
  (confirmado or em_producao) is what takes baixas; a delivered pedido is
  read only. `DesfazerBaixaService` (`DELETE /pedidos/:uuid/baixas/:uuid`)
  keeps the baixa struck through in the stage's history
  (`_historico_baixas`), refuses while a stage locked on it used those lines,
  and takes the pedido back to confirmado when the last one goes.
  `AndamentoDoPedido` gives each stage's lines done/total for the panel and
  the list (filtered by `?status=`).
- **Stock (Etapa 2.3e)**: a stage with `material:` adjusts the stock by its
  baixa's real metragem, one measure per material when the lines take
  several — `docs/dominio/estoque.md`. When the material is missing in the
  stock, the baixa launches its entry first (decided 05/11/2026; same file,
  "The material missing, launched at the baixa").
- **Reposição (4/4, decided 08-09/10/2026)**: a stage with `reposicao: true`
  (the Conferência) and fewer pieces than expected always sends them to a
  sub-pedido. `ContagemDaConferencia`: a short count (one line or a group)
  answers `:contar` with its lines — the `baixa` controller shows each
  line's count and **Impressão / Corte** checkboxes (checked; the conferente
  unchecks what doesn't need redoing) — and is saved with
  `baixas_producao.contagens`. `AcumularReposicaoService` keeps one **open
  reposição** per pedido (`Pedido#reposicao_em_aberto`: `reposicao_de`,
  status rascunho, out of production) and adds each line short as an
  `ItemReposicao` — file, part, DXF size, side, material, `corta`,
  `refazer_impressao`/`refazer_corte`, **pieces** (not pairs); the same line
  again adds pieces. `LiberarReposicaoService` confirms it when the
  Conferência's last line is done, or by "Gerar reposição" (`POST
  /pedidos/:uuid/gerar_reposicao`); a later shortage opens another.
  `baixa.reposicao` points at it. A line not redone skips that stage
  (`LinhasDeProducao::Linha#dispensa`; no Corte line without
  `refazer_corte`).
  `ImpressaoPedidoService`/`ProducaoPedidoService` build a reposição's lines
  from those items (`pecas_fixas`), so it goes through every stage again
  with the same pages; its own short Conferência makes another one. The
  original's delivery warns while a reposição isn't delivered.

## The Painel (Painel 1/4)

Decided 04/11/2026 (prototype in the canvas "Painel de produção"; the
decisions Q1–Q16 are in `docs/plano.md`, Etapa 2.10). `/painel`, first in the
menu, the Pedidos' permission (`pedidos › ver`) and visibility: a row per
pedido, a column per stage, from the files to the delivery.

- **Rows** — `PainelDeProducao.call(visiveis(Pedido))`: the pedidos not
  delivered (a reposição still gathering, rascunho, is left out — see
  Reposição below), and with
  `?entregues=1` the ones delivered in the last 7 days. Blocks by status
  until the turnos (2/4) and the programação (3/4): **Em andamento** (some
  baixa), **Prontos para começar** (confirmed, nothing holds it),
  **Pendentes de início** (draft, sent, waiting for material),
  **Entregues**. Inside a block: late, with a pendência, nearest deadline,
  arrival (`confirmado_em`, else `created_at`).
- **Columns and cells** — `LinhaDoPainel` + `CelulaDoPainel`: Arquivos (the
  file pendências of `PedidoBloqueiosService`), Comercial (the other
  pendências, the arte's approval, confirmed), Material (`AguardandoMaterial`:
  material or dublagem), Impressão, Corte, Estamparia (the tecido's Calandra
  too), Conferência (each from the stage's lines), Entrega. States: feita,
  andamento (x/y + bar), pode começar, travada ("espera Corte"), pendência,
  não tem, ainda não. Empty columns hide. A cliente final sees no material
  detail and the factory's pendências as "em análise pela fábrica". The
  Dublagem columns come with Dublagem 5b (4/4).
- **Opened** (painel_controller.js): the others dim, its cells are outlined,
  the faixa shows %, início (`confirmado_em`, else the first baixa), prazo,
  "previsão —" until 2/4, the path (`CaminhoDoPedido`: steps from the
  stages' `trava`, side by side when they don't wait for each other), what
  holds it and the links. "N itens" loads `GET /painel/pedidos/:uuid/itens`
  (`ItensDoPainel`: each item's own lines; the Corte is the pedido's).
- **Sector tabs** (Todos, Impressão, Corte…) keep the pedidos in that
  column's queue (pode começar, andamento, travada, pendência); the filters
  (tipo, cliente, só com pendência) and the counters run in the page.
- **Live** — `CanaisAoVivo.avisar_painel(pedido)` (Pedido after_commit on
  status, prazo, trash, client; BaixaProducao on create/update) sends only
  the uuid to `painel:equipe` and `painel:<client uuid>`; the page fetches
  `GET /painel/pedidos/:uuid` with its columns and swaps or moves the row
  (204 = it left the Painel; a cell in a hidden column reloads the page).
  A stock entry clearing "aguardando material" shows on the next load.
- **Reposição** (decided 05/11/2026, option a) — a reposição in production
  is a row **inside its original's** (`LinhaDoPainel#reposicoes`, rendered
  recursively, indented with a bar), in the original's block and order: the
  pair is one pedido for the counters, filters and sector tabs
  (`LinhaDoPainel#filas`/`#fora` join theirs). It takes the original's
  `prazo` (`LinhaDoPainel#prazo`). The original's Entrega is **travada
  "espera reposição"** while one is inside; one still gathering (rascunho)
  is not a row but a badge on the original, "↻ juntando reposição: N peças",
  with "gerar no resumo" in the faixa for the team. Once the original is
  delivered (anyway) or trashed, the reposição becomes a row of its own,
  "↻ reposição de #…". Live: a reposição's uuid answers with its original's
  row (`PainelDeProducao.linha` climbs to the open original), and delivering
  or trashing the original also tells its open reposições' rows.
  A stage the reposição doesn't redo (its Corte) leaves its path.
- **Data** — `pedidos.confirmado_em` / `confirmado_por_id` (written by
  `Pedido#marcar_confirmacao` on every way of confirming) and
  `prazo_entrega`, set by the team on the pedido's side panel, also after
  confirming (`PATCH /pedidos/:uuid/prazo`).
- **Speed** (measured 04/11/2026 on the dev data, 16 open pedidos: 1,8 s and
  2.300 queries): `EstadoDasEtapas` reads every stage once per pedido — the
  Impressão, Estamparia and Conferência lines are built once
  (`LinhasDeProducao` `memoria:`), the baixas come in one query for the whole
  Painel (`RegistrarBaixaService.situacao(…, fontes:)`) — and
  `ResolucaoDoItem` preloads each file's corte part (148 + 148 single
  queries in a pedido of 6 items). Now ~255 ms and 444 queries; the pedido's
  page and list use it too (`AndamentoDoPedido`). A cache of the rows comes
  only if it gets slow again.
