# Etapa 1.1 (3/5): the official catalog. Produto (with its grade of
# individual sizes) and the Modelo (category) under it, with an abbreviation,
# come from config/catalogo_oficial.yml (CatalogoOficial). A molde chooses
# the part of the grade it uses. Parts belong to the molde only: the
# category's peças (modelo_pecas) go away. No data migration (the beta starts
# empty); down recreates modelo_pecas empty.
class CreateCatalogoOficial < ActiveRecord::Migration[8.1]
  def up
    criar_produtos
    add_reference :modelos, :produto, foreign_key: true
    add_column :modelos, :abreviacao, :string
    add_index :modelos, :abreviacao, unique: true
    add_column :moldes, :tamanho_inicial, :string
    add_column :moldes, :tamanho_final, :string
    drop_table :modelo_pecas
  end

  def down
    create_table :modelo_pecas, id: false do |t|
      t.references :modelo, null: false, foreign_key: true
      t.references :peca, null: false, foreign_key: true
    end
    add_index :modelo_pecas, %i[modelo_id peca_id], unique: true
    remove_column :moldes, :tamanho_final
    remove_column :moldes, :tamanho_inicial
    remove_index :modelos, :abreviacao
    remove_column :modelos, :abreviacao
    remove_reference :modelos, :produto, foreign_key: true
    drop_table :produtos
  end

  private

  def criar_produtos
    create_table :produtos do |t|
      t.string :uuid, null: false
      t.string :nome, null: false
      t.json :grade, null: false, default: []
      t.datetime :deleted_at
      t.integer :deleted_by_id
      t.datetime :restored_at
      t.integer :restored_by_id
      t.timestamps
    end
    add_index :produtos, :uuid, unique: true
    add_index :produtos, :nome, unique: true
    add_index :produtos, :deleted_at
  end
end
