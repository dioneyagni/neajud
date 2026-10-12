# Etapa 2.5a (decided 12/10/2026): the arte says what kind of work it is —
# calçado (everything until now), etiqueta DTF, estampa corrida or cor lisa —
# with the number of its kind (DTF-863, CR-4114: per empresa, never reused)
# and "entra no catálogo" (the coleção geral, open to every client).
# sequencias keeps the last number of each kind.
class AddTipoToArtes < ActiveRecord::Migration[8.1]
  def change
    add_column :artes, :tipo, :string, null: false, default: "calcado"
    add_column :artes, :numero, :integer
    add_column :artes, :no_catalogo, :boolean, null: false, default: false
    add_index :artes, %i[tipo numero], unique: true
    add_index :artes, :no_catalogo

    create_table :sequencias do |t|
      t.string :nome, null: false
      t.integer :ultimo, null: false, default: 0
      t.timestamps
    end
    add_index :sequencias, :nome, unique: true
  end
end
