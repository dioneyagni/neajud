# "Repetir pedido" of a tecido pedido (decided 20/10/2026, the layout of the
# cor lisa canvas's "repetir pedido"): each item with the meters of last time
# and "metros desta vez" (Igual / Metade / Dobro), then a new draft with the
# same artes, fabrics, widths, owner, paper and prices (RepetirPedidoTecido).
# The team and the cliente final (his own pedidos, Visibilidade) may repeat.
#
# Usage: GET  /pedidos/:uuid/repetir
#        POST /pedidos/:uuid/repetir, metros[<item uuid>]=24,5
class RepeticoesPedidoTecidoController < ApplicationController
  include NumeroDigitado

  exige :pedidos, :editar
  before_action :set_origem

  def new
    @erro = RepetirPedidoTecido.erro(@origem)
    @itens = @origem.itens_pedido.includes(:materia_prima, :arquivo, arte: :arquivos).order(:id)
  end

  def create
    metros = metros_digitados
    errados = metros.reject { |_, valor| valor.match?(/\A\d+(\.\d+)?\z/) }
    return redirect_to repetir_pedido_path(@origem), alert: "Meters #{errados.values.map(&:inspect).join(", ")} are not numbers; expected meters like 12,5" if errados.any?

    resultado = RepetirPedidoTecido.call(@origem, metros: metros, pedidos: visiveis(Pedido))
    redirect_to pedido_path(resultado.pedido), notice: aviso_de_criado(resultado)
  rescue RepetirPedidoTecido::NaoRepetivel, ActiveRecord::RecordInvalid => e
    redirect_to repetir_pedido_path(@origem), alert: "Could not repeat ##{@origem.uuid.first(8)}: #{e.message}"
  end

  private

  def set_origem
    @origem = visiveis(Pedido).por_uuid!(params[:uuid])
  end

  # Blank is 0 m (the item stays out).
  def metros_digitados
    params.fetch(:metros, {}).to_unsafe_h.to_h { |uuid, valor| [ uuid.to_s, decimal_digitado(valor) || "0" ] }
  end

  def aviso_de_criado(resultado)
    texto = "Rascunho criado a partir do ##{@origem.uuid.first(8)}."
    resultado.de_fora.any? ? "#{texto} Ficaram de fora (na lixeira): #{resultado.de_fora.join(", ")}." : texto
  end
end
