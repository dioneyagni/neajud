# Artes

The arte envelope, kinds of work and numbers, the cor lisa, approval, referência/nome. Moved out of `AGENTS.md` on 19/10/2026; read it when working on this area.

## An arte is an envelope of files (Etapa 1.2, 2/3)

Decided 02/10/2026: **one arte per molde + referência + nome, one file per
part × size**. `Arte` (table `artes`) is the envelope; each file stays an
`Arquivo` with `arte_id` — versions, processing, preview, the automatic size
search and (until part 2) the client approval stay per file.

- **The arte's fields are the same in every file** (`MembroDeArte::CAMPOS_DA_ARTE`:
  client, molde, modelo, referência, nome). `after_update_commit` copies a
  change to the other files (`compartilhar_com_a_arte!`), which then drop a
  size of the old molde and queue their own search. ⚠️ Anything that writes
  these fields with `update_columns` must call `compartilhar_com_a_arte!`
  itself (`ajustar_referencia_e_nome!` does). Part (`peca_id`) and size
  (`tamanho_id`) stay per file.
- Every new non-corte `Arquivo` gets an arte of its own (`before_validation
  on: :create` — before_create ran after the belongs_to autosave, so the arte
  was never saved). Cortes have none.
- **Gallery:** `principais_das_artes` keeps one file per arte (its first) —
  one card, with `resumo_da_arte` ("2 files · Lateral 29-30, 31-32"). Any
  file's broadcast redraws that card. Batch delete trashes the whole arte.
- **Page:** `_arte_arquivos` lists `Arte#arquivos_por_parte`, each file with
  its thumbnail (`miniatura_do_arquivo`, lazy), with `ArteArquivosController`
  (`acrescentar`, `trazer`, `separar`; artes: editar). `trazer` brings the
  **marked** artes into this one (decided 05/10/2026: from the P's page mark
  the M and the G) — preview cards with a text filter (`trazer-artes`
  Stimulus controller), all checked with `JuntarArtesService.erro` before any
  moves. `JuntarArtesService` moves every file (trashed too) and refuses
  moving one to another molde or client; candidates are `artes_para_trazer`.
  `mesma_arte_em_outro_envelope` suggests, with its preview, an arte with
  the same molde, referência and nome.
- ⚠️ Rails 8 draws routes lazily outside eager_load, and a Solid Queue worker
  is its own process: two jobs rendering the card broadcast at once right
  after boot raced the drawing — one failed with `undefined method
  'arquivo_path'` and its file stayed "failed" (development too).
  `config/initializers/solid_queue.rb` draws them on worker start
  (`SolidQueue.on_worker_start`). Specs that need a preview assert
  `data-status="processed"` so a failed processing can't pass unnoticed.
- **Size from the file name:** `NomeDoArquivo` reads it (`tamanho`: "29-30",
  "P"; measures dropped from the name) into `tamanho_rotulo` at upload;
  `TamanhoAutoAssignService` tries it before the outline matcher when exactly
  one size of the file's part's cortes serves it (`Tamanho#atende_rotulo?`).
- **Client approval is the arte's** (part 2, decided 02/10/2026): `Aprovavel`
  is on `Arte`; `Arquivo` delegates `estado_aprovacao` & co. A request or an
  approval (`VersaoDeArte`) has `arte_id` and photographs `arquivo_version_ids`
  (the version in use of each active file) on create. Only the latest valid
  one counts: valid while every photographed file still in the arte keeps that
  version (and at least one is still there). A new version → "not sent" with
  "changed after the last approval" (`alterado_depois_da_aprovacao?` names the
  file); a file added later → still approved, marked "after the approval"
  (`depois_da_aprovacao?`). Joining artes brings the history along.
  `arquivo_id`/`arquivo_version_id` stay: the file whose page it came from
  (the attachment path uses its uuid). The gallery card shows a compact badge
  (`selo_aprovacao(arte, compacto: true)`).
- ⚠️ Read the arte's requests/approvals with a query (`validas.first`), not
  the loaded list: a new Arte starts with its lists loaded (empty), so a
  request created right after was invisible to it.
- **Piloto** (part 2b, decided 05/10/2026, `PapelNaArte`): `arquivos.papel`
  is `producao` (default) or `piloto` — one piloto per part of an arte
  (validated), the editable heavy master. It is in the approval's photo (a
  new version of it undoes the approval); production files of its part made
  before its newest version (v2 on) are `anterior_ao_piloto?` ("before the
  current piloto", a warning). It is never "the same arte uploaded again" of a
  production file (`artes_com_mesmo_nome` skips it). `ArteArquivosController`
  `tornar_piloto` (optional `junto_de`: the other arte joins first — the
  repeated-arte offer) / `voltar_para_producao`. For 3/3: production uses
  `producao`; the piloto only covers a sample (an arte asked only in the
  piloto's size with no production file for it).
- **Grouping at upload** (part 3, decided 05/10/2026): choosing files makes
  `upload_controller.js` POST their names and weights to
  `/arquivos/agrupamento` (`AgrupamentoDoUpload`: key = referência + nome
  from `NomeDoArquivo`, which also reads the part and drops "NEW"/"Copia";
  cortes alone). When something groups (`conferir`), the file list becomes the
  conference (`controllers/conferencia_upload.js`, a plain module): part,
  size, ★ piloto (suggested: PSD/AI/CDR, or ≥ 3× the median weight of the
  part), separate, join groups, add to an existing arte (suggested, never
  chosen). Sending: `POST /artes` makes each group's empty arte, then each
  file goes to `POST /arquivos` with `arquivo[arte_uuid|peca_uuid|tamanho_rotulo|papel]`
  (`Arte#novo_arquivo` copies the arte's fields; a DXF never joins an arte).
- One card per arte: it lists its files (`data-arte-arquivos`) and keeps
  polling while any of them is queued (`data-arte-em-fila`,
  `dados_da_arte_no_card`). A spec whose files must group by name writes them
  outside the repo (an `e2e-` prefix would be read as part of the name) —
  `e2e/upload-agrupamento.spec.js`.
- Pedidos still point at a file until Etapa 1.2 (3/3).
- E2E: `e2e/artes-arquivos.spec.js`.

## Kind of work, numbers and the coleção geral (Etapa 2.5a)

Decided 12/10/2026: an arte says what kind of work it is — `Arte#tipo`
(`TipoDaArte::TIPOS`: `calcado`, everything until then; `dtf`, `corrida`,
`cor_lisa`, the works without corte). A file is still an `Arquivo` of
category `artes`: upload, previews, versions, approval and grouping don't
change.

- **Chosen in the upload** (the gallery's "Kind of work", each group's in the
  conference — `upload_controller.js` / `conferencia_upload.js`): `POST
  /artes` takes `tipo`, a file sent alone takes `arquivo[tipo]`
  (`Arte.novo_do_tipo`); a DXF is always a corte. Changed on the arte page
  (`TiposDaArteController#update`, `Arte#trocar_tipo!`) while no pedido uses
  it and it has no molde — a work without corte takes no molde (validated in
  `MembroDeArte`), and its page hides molde, referência and the corte's size.
  Artes of different kinds are never joined (`JuntarArtesService`).
- **Numbers** (`Sequencia.proximo!`, table `sequencias`, one row per kind): a
  DTF or a corrida takes the next number when it gets the kind — `codigo`
  `DTF-863` / `CR-4114`, unique per kind, never reused (a new kind = a new
  number, a separated file = a new arte and number). Each empresa starts at 1;
  old hand-made numbers stay in the upload's file name. A DTF or a corrida is
  **named from its file name** on upload or when it gets the kind
  (`nomeada_pelo_arquivo?`, decided 14/10/2026: "872-ENCRUZILHADA DO SUL- P -
  1,6 X 1,7" → "ENCRUZILHADA DO SUL", the pedido shows "DTF-4 · ENCRUZILHADA
  DO SUL"; existing ones: `bin/rails artes:nomear_sem_corte`); the cor lisa is
  named by the system. The cor lisa's comes
  with its color family (2.5b). The full name of a work without corte starts
  with it: `DTF-863_Arcoverde_P`; the card shows it; the gallery filters by
  kind (`?tipo=`).
- **The coleção geral** (`Arte#no_catalogo`, "Entra no catálogo", a work
  without corte only; a cor lisa is born in it; marking is the team's —
  `exige_equipe`): every cliente final reads it. `Visibilidade::COLECAO_GERAL`
  adds it to `escopo(…, colecao_geral: true)`; `visiveis` passes it **only on
  GET/HEAD** — a write sees the client's own records, so no client changes
  another's work (an action that must read it in a write asks
  `visiveis(Model, colecao_geral: true)`). Live cards and pages follow
  (`CanaisAoVivo`; `Arquivo#redesenhar_cartao!` removes a card from the
  galleries that stop seeing it). On a work he only reads, a cliente final
  gets no controls, no client field and no answer to an approval
  (`do_proprio_cliente?`, used by `pode_editar_arquivo?`). Both sweeps carry a
  B work in the coleção geral.
- Outside the catálogo the client is required: for now a warning on its page
  ("Without client"); the pedido blocks it when DTF and corrida get theirs.
- **No parts, sides or piloto (2.5c, decided 12/10/2026)**: each file of a
  work without corte is already the editable one (production compacts a
  corrida's or cor lisa's file, the DTF gets its own in 2.6); a corrida or a
  cor lisa, sold by the meter, has no size either — a DTF keeps its.
  `Arte#usa_pecas?` / `usa_tamanhos?` / `campos_fora_do_tipo` say it;
  `MembroDeArte` clears those fields on every save (a part read from the
  file name never sticks), `trocar_tipo!` on the arte's files, and
  `PapelNaArte` refuses a piloto. The arte page, the card's summary and the
  upload's conference (the grouping's `tipos` carry `usa_pecas` /
  `usa_tamanhos`) hide them, with the paper consumption per piece. Their
  pedidos (2.6, 2.7) have no parts matrix, consumption or cost per pair.
  In a DTF upload the leading number doesn't separate the sizes (decided
  13/10/2026, `TipoDaArte::REFERENCIA_NAO_SEPARA`: "872/873/874-ENCRUZILHADA"
  P/M/G were numbered by hand one by one): `AgrupamentoDoUpload` takes the
  upload's `tipo`, offers existing artes of that kind only, and changing the
  upload's kind asks for the grouping again.
- **In pedidos**: the DTF since 2.6b1, the corrida and the cor lisa since
  2.7a (a tecido pedido — `docs/dominio/tecido.md`).
- E2E: `e2e/tipo-da-arte.spec.js`.

### The cor lisa, measured (Etapa 2.5b)

Decided 12/10/2026 (the calibrator by photo comes after the beta —
`docs/cor-lisa/`):

- **Measured per version** in CIE Lab: `MedirCorJob` (queued by
  `ArquivoVersion` when a cor lisa's version finishes processing, and by
  `TipoDaArte` when an arte becomes one) calls `MedidaDeCor` — ImageMagick:
  CMYK → sRGB by the previews' ICC profiles, averaged to one pixel; sRGB →
  Lab in Ruby — into `arquivo_versions.lab_l/lab_a/lab_b/cor_hex`. Injectable
  (`MedirCorJob.medidor`, `FakeMedidaDeCor` in specs). A file it can't read
  is logged and left "medindo…".
- **Named by the system** at the first measure (`Arte#batizar!`): the family
  from `config/familias_de_cor.yml` (`FamiliasDeCor`, LCh: grays by chroma,
  then the first band that holds the hue — fixed, the Neajud's, measured on
  the factory's samples) and the next number of that family
  (`Sequencia` "cor_lisa:laranja"): **`Laranja 1`** (no "v"). Family and
  number never change; a new version is a tone adjustment, measured again
  (the Lab follows the version in use). Unique key: tipo + familia + numero.
- **Near colors** (`CoresParecidas`, `DeltaE2000` — pure Ruby, checked
  against Sharma's pairs): on its page the colors within ΔE ≤ 3 —
  "praticamente igual" (≤ 1) or "parecida" — among those the person sees
  (`visiveis(Arte)`); the card only says "parecida", never which (it goes
  live to several clients). A notice, never a block. Limits in the YAML.
- **Material** optional (`artes.materia_prima_id`, set on its page —
  `TiposDaArteController#material`), not in the name.
- **"Cores"** (`/cores`, `CoresController`): the chart (`CartelaDeCores`: a
  column per 30° of hue, grays first; a row per band of lightness) and the
  table, by family and material.
- Restart the dev server after editing `config/familias_de_cor.yml`
  (`FamiliasDeCor` keeps it in memory).
- E2E: `e2e/cor-lisa.spec.js` (makes its solid-color files with `convert`).

## Art approval (Etapa 0.5, 4/4)

The client's approval of an arte is a **record, never a gate**: production and
confirming a pedido never wait for it (docs/plano.md, "Aprovação de arte").

- `AprovacaoArte` (table `aprovacoes_arte`): one approval of **one version**
  (`arquivo_version`), registered by a user (action `aprovar_arte`) with the
  channel the client used (`CANAIS`; "outro" needs `canal_detalhe`), the date,
  notes and an optional attachment. Cortes are never approved. Cancelled by
  mistake → `cancelar!` (kept in the history, struck through).
- **The client's own answer (Etapa 2.8, 4a):** two more states, both only
  after the request in force — `:alteracao_pedida` (an `AlteracaoArte`: the
  note shows on the arte's page and the badge; the team uses "Send for
  approval again") and `:aprovada_em_outra_versao` (he approved versions not
  in use: `_aprovacao_em_outra_versao` lists them with "Usar esta versão";
  once every one is in use the photo matches and the arte is `:aprovada`).
  The team's form never offers canal `sistema` (`AprovacaoArte::CANAL_SISTEMA`).
- **Nothing waits until it is sent** (changed before merge, 28/09/2026):
  `SolicitacaoAprovacao` = "Enviar para aprovação" for the version in use.
  `Aprovavel#estado_aprovacao` is `:nao_enviada` (default — no badge, no
  register button anywhere) → `:aguardando` (sent) → `:aprovada`. Registering
  an approval is refused unless it is `:aguardando` (service + controller).
  All of it is per **version in use** (`approved_version`): a new version
  starts over as not sent (`aprovada_versao_anterior?` tells an older one was
  approved). Both records share `VersaoDeArte` (version of that arte, artes
  only) and `Cancelavel` (cancel = kept in the history).
- ⚠️ **Naming:** `approved_version` / `ArquivoVersion#approved` / the
  `approve_version` route mean **"the version in use"**, not client approval.
  The UI says "Usar esta versão" / "Em uso"; keep "Aprovar/Aprovada" for
  `AprovacaoArte` only.
- **Per arte since Etapa 1.2 (2/3, part 2)** — see "An arte is an envelope
  of files": one request and one approval cover all the arte's files.
- **Attachment** (`AnexoDeAprovacao`): PNG/JPEG/PDF by **first bytes** (no
  ImageMagick/Ghostscript in the request), ≤ 20 MB, stored at
  `<STORAGE_BASE>/<arquivo uuid>/aprovacoes/<aprovação uuid>.<ext>` — the path
  is rebuilt from uuids + a fixed extension, never read from the column;
  always served as a download (`disposition: "attachment"`).
- Sent from the arte page ("Client approval" → "Send for approval");
  registered from there or from a pedido (badge + "Registrar aprovação" on each
  item, only while waiting — the approval is the arte's); `voltar_para` goes through `url_from`, so it
  can't redirect to another host.
- Portuguese plurals the app routes on need an inflection
  (`config/initializers/inflections.rb`: materiais, funcoes, aprovacoes,
  solicitacoes) —
  without it `resources :aprovacoes` generated `new_arquivo_aprovaco_path`.

## Referência, Nome and the full name (Etapa 1.1, 5/5)

An arte (`category: "artes"`) has a `Referencia` (a grouping inside one molde:
"19", "Fuel"; unique per molde ignoring case/accents — `TextoComparavel`) and a
free `nome` ("Bluey Azul"). `NomeDeArte` (concern in `Arquivo`):

- `nome_completo` — computed, never stored: molde code, referência, nome, part,
  size, empty pieces skipped (`001-TNS_19_Bluey Azul_Lateral_29-30`);
  `para_arquivo: true` drops accents and path characters. The arte download
  (`ArquivosController#download`) uses it as the file name.
- **Filled automatically** when the molde is chosen (`update_molde`) or the arte
  is linked from a pedido (`VincularArteService`): `ajustar_referencia_e_nome!`
  drops another molde's referência and reads blanks from the file name
  (`NomeDoArquivo`: leading number = referência, created in the molde when
  missing; parts and sizes left out — "19-BLUEY PTO-LINGUA" → 19, "BLUEY PTO").
  Edited on the arte page (`NomesArteController#update`).
- **Same arte uploaded twice** = same molde, referência, comparable nome and
  **size** (`artes_com_mesmo_nome`; per size until Etapa 1.2 groups sizes into
  one arte): the newer page offers "Make it a new version of that arte" →
  `JuntarArteRepetidaService` copies its file as the original's new version in
  use (`Arquivo#nova_versao!`, shared with `upload_version`) and trashes the
  newer record. Refused when the newer one is already in a pedido.
- Inflection: `referencia/referencias` (without it Rails looked for a table
  `referencia`).

### Tests of the arquivo page

- **Range slider (click-to-edit)**: E2E test must verify: (1) click display → editor appears (hidden class removed), (2) edit value + Enter/blur → display and hidden input updated, (3) editor hidden again after commit

### Arquivo page details

- Time fields use the `h:mm` mask (e.g. `130` → 1:30, `2430` → 24:30), parsed by
  `ArquivosController#parse_hmm`.

- Form upload needs `html: { enctype: "multipart/form-data", data: { turbo: false } }`
