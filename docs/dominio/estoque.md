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
piece, else the typed `largura_papel_mm`. Automatic consumption at
confirmation, the adjustment by the real metragem, "aguardando material"
and the dublagem come later (docs/plano.md, Etapa 2.3).
