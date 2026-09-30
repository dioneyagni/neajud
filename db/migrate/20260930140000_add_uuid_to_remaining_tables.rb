# Etapa 1.1 (1/2): every entity gets a uuid, the only identifier that leaves
# the server (URLs, JSON, form values); the integer id stays as the internal
# key. Existing rows (development samples — the beta starts empty) are
# backfilled so they keep working. Left out on purpose: pure join tables
# (arquivo_modelos, molde_pecas), sessions (signed cookie), the 1:1
# arquivo_image_metadata and itens_pedido_grade (addressed by tamanho name
# inside its item), which never appear on their own.
class AddUuidToRemainingTables < ActiveRecord::Migration[8.1]
  TABELAS = %i[
    clients modelos moldes pecas tamanhos
    materia_primas grupo_materiais cor_materiais movimento_estoques
    item_pedido_pecas modelo_pecas cut_layers
    exclusao_logs arquivo_vinculo_logs
  ].freeze

  def up
    TABELAS.each do |tabela|
      add_column tabela, :uuid, :string
      preencher_uuids(tabela)
      change_column_null tabela, :uuid, false
      add_index tabela, :uuid, unique: true
    end
  end

  def down
    TABELAS.each { |tabela| remove_column tabela, :uuid }
  end

  private

  def preencher_uuids(tabela)
    select_values("SELECT id FROM #{tabela}").each do |id|
      execute "UPDATE #{tabela} SET uuid = #{quote(SecureRandom.uuid)} WHERE id = #{id.to_i}"
    end
  end
end
