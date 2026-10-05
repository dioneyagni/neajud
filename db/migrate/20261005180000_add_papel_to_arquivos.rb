# Etapa 1.2 (2/3, parte 2b): each part of an arte has one piloto — the
# editable, heavy master file (e.g. a 78 MB layered TIF) — and its grade of
# production files, the light ones used day to day (decided 05/10/2026).
# Every existing file is production; the piloto is chosen on the arte page.
class AddPapelToArquivos < ActiveRecord::Migration[8.1]
  def change
    add_column :arquivos, :papel, :string, null: false, default: "producao"
  end
end
