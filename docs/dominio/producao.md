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
