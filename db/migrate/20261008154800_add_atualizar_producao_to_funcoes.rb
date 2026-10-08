# Etapa 2.2 (2/3): the new special action "atualizar_producao" (giving a
# production stage's baixa) goes to the default Admin and Produção funções
# that already exist, as docs/plano.md's table says ("Atualizar status da
# produção": Dono, Admin, Produção). Other funções: the dono grants it.
class AddAtualizarProducaoToFuncoes < ActiveRecord::Migration[8.1]
  class Funcao < ActiveRecord::Base
    self.table_name = "funcoes"
  end

  NOMES = %w[Admin Produção].freeze

  def up
    Funcao.where(nome: NOMES, dono: false).find_each do |funcao|
      funcao.update_columns(acoes: (Array(funcao.acoes) | [ "atualizar_producao" ]))
    end
  end

  def down
    Funcao.where(nome: NOMES, dono: false).find_each do |funcao|
      funcao.update_columns(acoes: Array(funcao.acoes) - [ "atualizar_producao" ])
    end
  end
end
