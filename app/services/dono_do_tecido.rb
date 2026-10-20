# Whose stock a pedido's fabric comes from (Etapa 2.3d1, decided 19/10/2026):
# a cascade cliente → molde → pedido, each level blank = inherit the one
# above, nothing set = "cliente". A tecido item has no molde (cliente →
# pedido); a calçado item reads the molde of its file, like its price
# (Molde#preco_do_par), so a pedido of several moldes may take fabric from
# different owners unless the pedido says. Confirming writes each item's
# (ItemPedido#dono_tecido), and a written item no longer follows the levels.
#
# Usage: DonoDoTecido.do_item(item)       # => #<Origem dono="empresa", nivel=:molde>
#        DonoDoTecido.do_pedido(pedido)   # the pedido's, without the moldes
#        DonoDoTecido.herdado(pedido)     # what a blank pedido inherits, for its select
class DonoDoTecido
  DONOS = %w[cliente empresa].freeze
  PADRAO = "cliente"
  ROTULOS = { "cliente" => "Do cliente", "empresa" => "Da empresa" }.freeze

  Origem = Struct.new(:dono, :nivel) do
    def empresa? = dono == "empresa"
    def rotulo = ROTULOS.fetch(dono)
  end

  # do_pedido: false skips the pedido's own choice (what it would inherit).
  def self.do_item(item, do_pedido: true)
    return Origem.new(item.dono_tecido, :item) if item.dono_tecido

    molde = item.arquivo&.molde unless item.pedido.tecido?
    niveis = [ [ molde&.dono_tecido, :molde ], [ cliente_do_item(item)&.dono_tecido, :cliente ] ]
    niveis.unshift([ item.pedido.dono_tecido, :pedido ]) if do_pedido
    primeiro(niveis)
  end

  # The pedido as a whole: what its written items say (confirmed), else its
  # own choice, else its client's.
  def self.do_pedido(pedido)
    gravado = pedido.itens_pedido.filter_map(&:dono_tecido).first
    return Origem.new(gravado, :item) if gravado

    primeiro([ [ pedido.dono_tecido, :pedido ], [ pedido.client&.dono_tecido, :cliente ] ])
  end

  # What each item would take with the pedido blank: one Origem, or nil
  # when its moldes differ.
  def self.herdado(pedido)
    itens = pedido.itens_pedido.to_a
    return primeiro([ [ pedido.client&.dono_tecido, :cliente ] ]) if itens.empty? || pedido.tecido?

    origens = itens.map { |item| do_item(item, do_pedido: false) }
    origens.map(&:dono).uniq.one? ? origens.first : nil
  end

  def self.cliente_do_item(item)
    item.pedido.client || item.arquivo&.client
  end

  def self.primeiro(niveis)
    dono, nivel = niveis.find { |valor, _| valor }
    dono ? Origem.new(dono, nivel) : Origem.new(PADRAO, :padrao)
  end
  private_class_method :cliente_do_item, :primeiro
end
