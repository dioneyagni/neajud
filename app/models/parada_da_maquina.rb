# A machine a stop takes (Máquinas 3/5a, decided 24/11/2026): the whole
# machine, in every stage it does (Q1a). A pure join row.
class ParadaDaMaquina < ApplicationRecord
  self.table_name = "excecoes_calendario_maquinas"

  belongs_to :excecao_calendario, inverse_of: :paradas_das_maquinas
  belongs_to :maquina
end
