# Each material's balance in meters, split by owner (Etapa 2.3, decided
# 09/10/2026): the empresa's own stock (movements without client) and each
# client's material kept here. One query for the Materials page.
#
# Usage: saldos = SaldosDeEstoque.call
#        saldos.empresa(material) # => 120.5
#        saldos.por_cliente(material) # => { <Client MKS> => 30.0 }
class SaldosDeEstoque
  def self.call
    new
  end

  def initialize
    linhas = MovimentoEstoque.group(:materia_prima_id, :client_id)
                             .pluck(:materia_prima_id, :client_id, Arel.sql("SUM(CASE WHEN tipo = 'entrada' THEN quantidade ELSE -quantidade END)"))
    @clientes = Client.where(id: linhas.map(&:second).compact.uniq).index_by(&:id)
    @saldos = linhas.each_with_object(Hash.new { |h, k| h[k] = {} }) { |(material, cliente, saldo), mapa| mapa[material][cliente] = saldo.to_f }
  end

  def empresa(material)
    @saldos[material.id][nil].to_f
  end

  def por_cliente(material)
    @saldos[material.id].except(nil).to_h { |cliente_id, saldo| [ @clientes[cliente_id], saldo ] }.sort_by { |cliente, _| cliente.name }.to_h
  end

  def total(material)
    @saldos[material.id].values.sum
  end
end
