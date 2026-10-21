# What the stock adjustment by the real looks like (Etapa 2.3e, decided
# 20/10/2026): the baixa's fields when its lines take several materials, what
# each baixa did to the stock in the stage's history, and the pedido's
# consumption so far on its panel — a cliente final sees his own fabric only,
# never the empresa's paper or stock (as AguardandoMaterialHelper).
module AjusteDoEstoqueHelper
  # The materials a whole-stage baixa asks one measure of; {} for one or none.
  # Usage: materiais_da_baixa(pedido, etapa, abertas) # => { oxford => 4.0, helanca => 6.0 }
  def materiais_da_baixa(pedido, etapa, situacoes)
    por_material = MateriaisDasLinhas.por_material(pedido, etapa, situacoes.map(&:linha))
    por_material.size > 1 ? por_material : {}
  end

  # Usage: ajuste_da_baixa(baixa) # => "estoque: +1,2 m Oxford-Azul-1.60 (MKS); −0,3 m Papel-Branco-1.60 (Empresa)"
  #        (nil when the stage doesn't take material or used what it expected)
  def ajuste_da_baixa(baixa, etapa)
    return unless etapa.ajusta_estoque?
    return "sem saída do estoque" unless baixa.pedido.movimentos_estoque.da_confirmacao.exists?
    return if baixa.ajustes_estoque.empty?

    "estoque: " + baixa.ajustes_estoque.includes(:materia_prima, :client).map { |m| "#{sinal(m)}#{metros(m.quantidade)} #{m.materia_prima.nome_completo} (#{m.dono})" }.join("; ")
  end

  Consumo = Struct.new(:materia_prima, :client, :saida, :ajustes, keyword_init: true) do
    def real = saida + ajustes
  end

  # The pedido's materials: what went out at confirmation and the standing
  # adjustments, per material × owner.
  # Usage: consumo_do_pedido(pedido).first.real # => 13.2
  def consumo_do_pedido(pedido)
    movimentos = pedido.movimentos_estoque.que_contam.includes(:materia_prima, :client).order(:id).to_a
    movimentos = movimentos.select { |m| m.client && m.client == Current.user.cliente } if cliente_final?
    movimentos.group_by { |m| [ m.materia_prima, m.client ] }.map do |(material, client), grupo|
      saida = grupo.reject(&:baixa_producao_id).sum(&:quantidade)
      ajustes = grupo.select(&:baixa_producao_id).sum { |m| m.tipo == "saida" ? m.quantidade : -m.quantidade }
      Consumo.new(materia_prima: material, client: client, saida: saida, ajustes: ajustes)
    end
  end

  # Usage: ajuste_em_metros(1.2) # => "+1,2 m"; ajuste_em_metros(-0.3) # => "−0,3 m"
  def ajuste_em_metros(valor)
    "#{valor.negative? ? "−" : "+"}#{metros(valor.abs)}"
  end

  private

  def sinal(movimento)
    movimento.tipo == "saida" ? "+" : "−"
  end
end
