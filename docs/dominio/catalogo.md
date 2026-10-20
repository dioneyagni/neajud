# Catálogo, moldes e cortes

Official catalog, molde code, a corte's grade type, the automatic size search and preparing a corte's sizes. Moved out of `AGENTS.md` on 19/10/2026; read it when working on this area.

## Official catalog (Etapa 1.1, 3/5)

Produto (with its grade of individual sizes) and Modelo (the category, with
an abbreviation) are the **official Neajud list**, the same in every
company: `config/catalogo_oficial.yml`, with fixed uuids.

- **Loading:** `CatalogoOficial.sincronizar!` (`bin/rails catalogo:sincronizar`)
  runs after every `db:prepare` (so on deploy and `bin/setup`) and in `bin/e2e`
  after the truncate. Safe to repeat: matched by uuid, updated in place; what
  left the file goes to the trash (`changed_by: "catalogo_oficial"`), comes
  back if listed again. A record with the same name but not in the list (a
  dev sample) is adopted — it takes the official uuid.
- **Read only for the company:** `/modelos` lists them by produto; no
  create/edit/destroy routes, and they aren't restorable from `/lixeira`.
  To add one, edit the YAML in a PR.
- **Molde:** chooses a stretch of its produto's grade (`tamanho_inicial`,
  `tamanho_final`, validated; `Molde#grade` lists it) and has its **own parts**
  (`molde_pecas`, added/removed on the molde page, each "corta / não corta").
  Categories have no pieces: nothing is copied from them.
- ⚠️ **A modelo is shared by every client**, so anything that falls back to
  "cortes of the same modelo" must stay inside the client:
  `Arquivo.cortes_do_molde` and `MoldMatchService` only take cortes of the
  molde's / arte's client (an arte picked another client's corte and sizes
  when the fallback didn't).
- **A molde's cortes come from the molde, never from "the category":** the
  arte's Size Selection (`/pecas/for_cascade` and `/tamanhos/for_cascade`,
  called with `molde_uuid`) lists `Arquivo.cortes_do_molde` like the automatic
  search and the pedido. Filtering by category + client listed nothing once a
  molde moved to the official "Tenis" while its cortes kept the old category,
  and could list another molde's cortes (fixed 01/10/2026).
- E2E: `e2e/support/catalogo.js` (`modeloOficial`, `adicionarPartes`); specs
  pick an official modelo instead of registering one — use a different one
  per spec when cortes could meet in the fallback.

## Molde code (Etapa 1.1, 4/5)

A molde is named `NNN-ABR` + optional suffix ("002-TNS Furado"):

- `numero`: per client, all categories together, **never reused** (the max
  includes trashed moldes; unique index `client_id, numero`). The client is
  fixed once created (validation + the edit dialog hides it).
- The abbreviation is the modelo's, so changing the modelo turns 002-TNS into
  002-JGG; `sufixo` is free text. `nome` **stores the assembled name**
  (`Molde#montar_nome`, before validation) for search and sorting — never
  assign it directly. When the official list changes an abbreviation,
  `CatalogoOficial` calls `Molde#atualizar_nome!` on that modelo's moldes.
- A modelo is required on create (the code needs its abbreviation).
- `variacao_de`: a variation of any molde, **also another client's** (it
  follows its own client's numbering). Set only on create; it is born with the
  base's modelo and grade (when not given), its parts (with "corta/não corta")
  and its corte links (`arquivo_moldes`) — a copy, not inheritance (that is
  Fase 5). `version`, `base_id`, `published_at` exist for Fase 5, unused.
- Forms send `molde[sufixo]`, never `molde[nome]`; JSON search results carry
  `nome`, `codigo` and `sufixo` (E2E specs find their molde by `sufixo`).

## Grade type of a corte (Etapa 1.2, 1/3)

A corte has a `tipo_grade` (`GradeDoCorte::TIPOS`: par, impar, pmg, furada)
and each `Tamanho` keeps its label in `nome` (what the arte's full name and
the pedido show, e.g. "29-30", "P") plus `numeros`, the individual sizes it
serves (strings, like `Molde#grade`).

- **Deduction:** while a corte has no type, the Mold Organization form is
  prefilled by `GradeDoCorte.deduzir` (`grade_proposta` helper). One number
  per size is the **last** of the pair ("24, 26…" → Par 23-24…; "35, 37…" →
  Ímpar 34-35…); written ranges stay; "Size N" deduces nothing. The DXF
  detection takes the numbers from the range in the filename ("35 AO 43").
- **Saving:** `organize` reads every row first (`TamanhoReplacementService`
  with `tipo:` → `GradeDoCorte.ler`, which raises `Invalido` naming the value
  and the expected shape); one bad row refuses the whole save, nothing
  written. Tamanhos are updated **in place by position** — uuid, preview,
  extracted DXF and linked artes stay; only rows past the new list go.
- **Coverage** (`CoberturaDaGrade`) is a **warning, never a block** (decided
  01/10/2026): missing / repeated numbers of `Molde#grade`, shown on the corte
  page (linked moldes) and on the molde page's parts.
- ⚠️ Pedido grades (`itens_pedido_grade.tamanho_nome`) are keyed by the
  tamanho's name: relabeling an old corte ("24" → "23-24") leaves draft pedidos
  pointing at the old name. Fine for the sample data; Etapa 1.2 (3/3) rebuilds
  the pedido on individual sizes.
- E2E: `e2e/arquivos-tipo-grade.spec.js`.

## Background work on cortes (Etapa 0.6)

**Automatic tamanho search (Etapa 0.6, 1/3):** picking an arte's molde
(`update_molde`) no longer runs `MoldMatchService` in the request (measured up
to 37 s on dev data): `Arquivo#buscar_tamanho_em_fila!` sets
`buscando_tamanho_desde` and enqueues `TamanhoAutoAssignJob`, which always
clears it and `broadcast_refresh`es the arte page (found or not). Meanwhile
Size Selection shows "Procurando tamanho…" with the `processamento`
controller polling `GET /arquivos/:uuid/busca_tamanho.json`; a mark older than
10 minutes counts as over (a dead job never leaves the page waiting).
`TamanhoAutoAssignJob.matcher` is injectable (`FakeMoldMatcher` in specs).

**Preparing a corte's tamanhos (Etapa 0.6, 2/3 + 3/3):** `organize` and
`configure_layers` only save what was chosen and call
`Arquivo#preparar_tamanhos_em_fila!(redetectar:)` → `PreparacaoTamanhosJob`
(re-detects via `DxfOrganizationService.call` after a failed organize, else
`generate_tamanho_previews`). Each size's DXF is extracted once, to
`Tamanho#dxf_extraido_path` (`<version>/tamanho_previews/<position>.dxf`,
next to its preview), and production's download serves that file — extracting
it on the spot only if asked before it is ready or older than the version
(`tmp/tamanho_extracts/` is no longer used). The corte page shows "Preparando
os tamanhos…" polling `GET /arquivos/:uuid/preparacao_tamanhos.json`; same
10-minute expiry (`Arquivo::TAREFA_EM_FILA_EXPIRA`). The organizer is
injectable (`PreparacaoTamanhosJob.organizador`, `FakeOrganizadorDxf`).
Previews feed the automatic tamanho search: an arte linked while its corte is
still preparing falls back to dimensions or to picking the size by hand.
