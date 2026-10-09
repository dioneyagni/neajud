# Etapa 2.3 (decided 09/10/2026), stock kept by hand for now:
# - materia_primas.tipo: tecido, papel or filme; preco_metro: the sale price
#   per meter (the entries' valor stays the purchase cost);
# - movimento_estoques without client = the empresa's own stock;
# - empresas.papel_padrao: the paper whose width gives an arte's meters per
#   piece (largura_papel_mm stays as the fallback while no paper is set).
class EstoqueDaEmpresaETiposDeMaterial < ActiveRecord::Migration[8.1]
  def change
    add_column :materia_primas, :tipo, :string, null: false, default: "tecido"
    add_column :materia_primas, :preco_metro, :decimal, precision: 10, scale: 2
    change_column_null :movimento_estoques, :client_id, true
    add_reference :empresas, :papel_padrao, foreign_key: { to_table: :materia_primas }
  end
end
