# A tecido item's prices and minimum meters (Etapa 2.7b, decided 17/10/2026):
# the print per meter — edited on the pedido, else the client's agreed, else
# the dono's (the same for a corrida and a cor lisa, any width) — and, when
# the fabric is the empresa's, the fabric per meter — edited, else the
# material's price. Each keeps its starting one beside, so the discount is
# measured; confirming writes both (confirmar_precos_tecido!), and a
# confirmed item reads what was written.
# Below the dono's minimum (per item) it waits for someone with "aprovar
# abaixo do mínimo"; the approval holds while the meters are the ones
# approved, so changing them asks again — and who approved stays recorded.
#
# Usage: item.preco_impressao_efetivo # => 18.0
#        item.aprovar_minimo!(Current.user) if item.abaixo_do_minimo?
module PrecosDoItemTecido
  extend ActiveSupport::Concern

  included do
    belongs_to :minimo_aprovado_por, class_name: "User", optional: true
    validates :preco_impressao_metro, :preco_tecido_metro, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  end

  def preco_impressao_de_partida
    return preco_impressao_metro_partida if precos_gravados?

    pedido.client&.preco_impressao_metro_tecido || Empresa.atual&.preco_impressao_metro_tecido
  end

  def preco_impressao_efetivo
    preco_impressao_metro || preco_impressao_de_partida
  end

  # Only the empresa's fabric is charged (decided in 2.3, 09/10/2026); whose
  # it is cascades cliente → pedido since 2.3d1 (DonoDoTecido).
  def cobra_tecido?
    DonoDoTecido.do_item(self).empresa?
  end

  def preco_tecido_de_partida
    return preco_tecido_metro_partida if precos_gravados?

    cobra_tecido? ? materia_prima&.preco_metro : nil
  end

  def preco_tecido_efetivo
    cobra_tecido? ? preco_tecido_metro || preco_tecido_de_partida : nil
  end

  # The dono's minimum per item; nil when none is set.
  def metragem_minima
    minimo = Empresa.atual&.metragem_minima_tecido
    minimo&.positive? ? minimo : nil
  end

  def abaixo_do_minimo?
    minimo = metragem_minima
    minimo.present? && metros.to_d.positive? && metros.to_d < minimo
  end

  # Approved for the meters it has now.
  def minimo_aprovado?
    minimo_aprovado_por_id.present? && minimo_aprovado_metros.present? && minimo_aprovado_metros == metros
  end

  # Usage: item.aprovar_minimo!(Current.user)
  def aprovar_minimo!(user)
    update!(minimo_aprovado_por: user, minimo_aprovado_em: Time.current, minimo_aprovado_metros: metros)
  end

  # Writes the starting and charged prices (confirming).
  def confirmar_precos_tecido!
    update!(preco_impressao_metro_partida: preco_impressao_de_partida, preco_impressao_metro: preco_impressao_efetivo,
            preco_tecido_metro_partida: preco_tecido_de_partida, preco_tecido_metro: preco_tecido_efetivo)
  end

  private

  # A draft (even in the trash) follows the cascade: only confirming writes.
  def precos_gravados?
    pedido.tecido? && Pedido::ANTES_DA_CONFIRMACAO.exclude?(pedido.status)
  end
end
