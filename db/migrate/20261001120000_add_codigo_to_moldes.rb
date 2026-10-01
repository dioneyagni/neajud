# Etapa 1.1 (4/5): a molde's code `NNN-ABR` — a number per client (all
# categories together, never reused), the modelo's abbreviation and a free
# suffix ("002-TNS Furado"); `nome` keeps the assembled name for search and
# sorting (Molde#montar_nome). A molde can be a variation of another (even of
# another client's), and gets the version columns the catalog versioning of
# Fase 5 will use. Existing rows (development samples) are numbered per
# client in creation order, their old name becoming the suffix.
class AddCodigoToMoldes < ActiveRecord::Migration[8.1]
  def up
    add_column :moldes, :numero, :integer
    add_column :moldes, :sufixo, :string
    add_reference :moldes, :variacao_de, foreign_key: { to_table: :moldes }
    add_column :moldes, :version, :integer, null: false, default: 1
    add_reference :moldes, :base, foreign_key: { to_table: :moldes }
    add_column :moldes, :published_at, :datetime
    numerar_existentes
    change_column_null :moldes, :numero, false
    remove_index :moldes, %i[nome client_id]
    add_index :moldes, %i[client_id numero], unique: true
  end

  def down
    remove_index :moldes, %i[client_id numero]
    execute "UPDATE moldes SET nome = sufixo WHERE sufixo IS NOT NULL AND sufixo <> ''"
    add_index :moldes, %i[nome client_id], unique: true
    remove_column :moldes, :published_at
    remove_reference :moldes, :base, foreign_key: { to_table: :moldes }
    remove_column :moldes, :version
    remove_reference :moldes, :variacao_de, foreign_key: { to_table: :moldes }
    remove_column :moldes, :sufixo
    remove_column :moldes, :numero
  end

  private

  def numerar_existentes
    select_rows("SELECT id, client_id, nome FROM moldes ORDER BY client_id, id").group_by { |_, client, _| client }.each_value do |linhas|
      linhas.each.with_index(1) do |(id, _, nome), numero|
        execute "UPDATE moldes SET numero = #{numero}, sufixo = #{quote(nome)} WHERE id = #{id.to_i}"
      end
    end
    # Same shape as Molde#montar_nome: "001-TNS 19-20-25" ("001 19-20-25"
    # while the modelo has no abbreviation, e.g. a trashed dev sample).
    execute <<~SQL
      UPDATE moldes SET nome = printf('%03d', numero)
        || COALESCE('-' || (SELECT abreviacao FROM modelos WHERE modelos.id = moldes.modelo_id), '')
        || ' ' || sufixo
    SQL
  end
end
