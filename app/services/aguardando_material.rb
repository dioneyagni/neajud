# Which pedidos wait for material (Etapa 2.3d2, decided 19/10/2026): per
# material × owner, the outs in the order they were made (a pedido's at its
# confirmation, the ones by hand too) and the entries cover the oldest
# first; a pedido whose out goes past what came in waits, missing the
# difference. Computed on the fly, never stored: an entry clears it by
# itself, a trashed pedido stops counting (MovimentoEstoque.que_contam). It
# never blocks. A delivered pedido still counts in the order but no longer
# shows as waiting.
#
# It reads every movement — the paper is the empresa's even on a client's
# pedido — so what a person sees of it is filtered by who asks
# (AguardandoMaterialHelper).
#
# Usage: aguardando = AguardandoMaterial.call
#        aguardando.do_pedido(pedido) # => [#<Falta materia_prima=Oxford client=MKS metros=12.5>]
#        aguardando.pedido_ids        # => [42, 57]
#        aguardando.do_material(oxford) # => [#<Falta …>, …] (one per waiting pedido)
class AguardandoMaterial
  Falta = Struct.new(:pedido_id, :materia_prima, :client, :metros, keyword_init: true)

  def self.call(movimentos = MovimentoEstoque.all)
    new(movimentos)
  end

  def initialize(movimentos = MovimentoEstoque.all)
    linhas = movimentos.que_contam.order(:created_at, :id).pluck(:materia_prima_id, :client_id, :tipo, :quantidade, :pedido_id)
    faltas = linhas.group_by { |linha| linha.first(2) }.flat_map { |(material, client), grupo| faltas_do_grupo(material, client, grupo) }
    @faltas = sem_entregues(faltas)
    @materiais = MateriaPrima.where(id: @faltas.map(&:materia_prima)).index_by(&:id)
    @clientes = Client.where(id: @faltas.filter_map(&:client)).index_by(&:id)
  end

  def pedido_ids
    @faltas.map(&:pedido_id).uniq
  end

  def do_pedido(pedido)
    @faltas.select { |falta| falta.pedido_id == pedido.id }.map { |falta| completa(falta) }
  end

  def do_material(material)
    @faltas.select { |falta| falta.materia_prima == material.id }.map { |falta| completa(falta) }
  end

  private

  # Entries cover the outs in order; what passes them is missing.
  def faltas_do_grupo(material, client, grupo)
    entradas = grupo.sum { |linha| linha[2] == "entrada" ? linha[3] : 0 }
    acumulado = 0
    grupo.select { |linha| linha[2] == "saida" }.filter_map do |_, _, _, quantidade, pedido_id|
      acumulado += quantidade
      falta = [ acumulado - entradas, quantidade ].min
      Falta.new(pedido_id: pedido_id, materia_prima: material, client: client, metros: falta.to_f.round(2)) if pedido_id && falta.positive?
    end
  end

  def sem_entregues(faltas)
    entregues = Pedido.where(id: faltas.map(&:pedido_id), status: "entregue").pluck(:id)
    faltas.reject { |falta| entregues.include?(falta.pedido_id) }
  end

  def completa(falta)
    falta.dup.tap do |f|
      f.materia_prima = @materiais[falta.materia_prima]
      f.client = @clientes[falta.client]
    end
  end
end
