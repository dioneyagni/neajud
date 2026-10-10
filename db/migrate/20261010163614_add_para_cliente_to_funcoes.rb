# Etapa 2.8 (2/5, decided 10/10/2026): a função is for the team or for
# clientes finais (`para_cliente`), and the empresas already configured get
# the default "Cliente final" (Funcao::PADRAO) — a new instance gets it from
# ConfiguracaoInicialService.
class AddParaClienteToFuncoes < ActiveRecord::Migration[8.1]
  class Funcao < ActiveRecord::Base
    self.table_name = "funcoes"
  end

  NOME = "Cliente final".freeze
  NIVEIS = { "pedidos" => 1, "clientes" => 1, "artes" => 1, "catalogo" => 1, "estoque" => 1, "lixeira" => 0 }.freeze

  def up
    add_column :funcoes, :para_cliente, :boolean, default: false, null: false
    Funcao.reset_column_information
    # No funções yet = an instance not configured: the setup creates them.
    return unless Funcao.exists?
    return if Funcao.where("LOWER(nome) = ?", NOME.downcase).exists?

    Funcao.create!(uuid: SecureRandom.uuid, nome: NOME, para_cliente: true, niveis: NIVEIS, acoes: [])
  end

  def down
    # Only while nobody uses it; a used one stays, as a team função.
    Funcao.where(nome: NOME, para_cliente: true).where("id NOT IN (SELECT funcao_id FROM vinculos)").delete_all
    remove_column :funcoes, :para_cliente
  end
end
