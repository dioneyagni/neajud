# Etapa 1.1 (5/5): an arte is marked with a Referência (a grouping of artes
# inside one molde: "19", "Fuel") and a Nome ("Bluey Azul"); together with the
# molde's code, the part and the size they make the arte's full name,
# computed, never stored: 001-TNS_19_Bluey Azul_Lateral_29-30. Referências
# belong to one molde each; names are unique per molde ignoring case and
# accents (checked in the model — SQLite can't index the transliteration).
class CreateReferencias < ActiveRecord::Migration[8.1]
  def change
    create_table :referencias do |t|
      t.string :uuid, null: false
      t.references :molde, null: false, foreign_key: true
      t.string :nome, null: false
      t.timestamps
    end
    add_index :referencias, :uuid, unique: true

    add_reference :arquivos, :referencia, foreign_key: true
    add_column :arquivos, :nome, :string
  end
end
