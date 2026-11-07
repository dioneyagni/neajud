# How the Painel says the programação (Painel 3/4a): the impact window's
# title, a previsão in it, and each line of a pedido's "Histórico da
# programação" (the team's only).
module ProgramacaoHelper
  # Usage: titulo_do_impacto(impacto) # => "#c210aa12 · Impressão: 3º → 1º"
  def titulo_do_impacto(impacto)
    return "Fila da #{LinhaDoPainel::COLUNAS.fetch(impacto.setor)}: voltar tudo à ordem de chegada (#{pluralize(impacto.movimentos.size, "movida", plural: "movidas")})" if impacto.tipo == :setor

    vez = impacto.vez
    nome = "##{vez.pedido.uuid.first(8)} · #{vez.etapa.nome}"
    return "#{nome}: voltar à ordem de chegada (#{impacto.de}º → #{impacto.para}º)" if impacto.tipo == :chegada

    "#{nome}: #{impacto.de}º → #{impacto.para}º"
  end

  # Usage: previsao_do_impacto(nil) # => "sem previsão"
  def previsao_do_impacto(momento)
    momento ? momento_da_fila(momento) : "sem previsão"
  end

  # A movement as the pedido's history says it: its own, or the one that pushed it.
  # Usage: linha_do_historico(movimento, pedido)
  #        # => "05/11 14:20 · Dione passou o #c210aa12 à frente na Impressão (3º → 1º) · cliente pediu urgência · este pedido: qui 12/11 15:30 → sex 13/11 09:00"
  def linha_do_historico(movimento, pedido)
    partes = [ "#{movimento.created_at.strftime("%d/%m %H:%M")} · #{movimento.user.nome} #{acao_do_movimento(movimento)}", movimento.motivo.presence ]
    partes << efeito_do_movimento(movimento, pedido)
    partes.compact.join(" · ")
  end

  # The pedido's movements, read once per page (the Painel gives them all).
  def historico_da_programacao(pedido)
    @historicos ||= {}
    @historicos[pedido.id] ||= visiveis(MovimentoDaFila).do_pedido(pedido).to_a
  end

  private

  def acao_do_movimento(movimento)
    etapa = EtapasProducao.etapa(movimento.pedido.tipo, movimento.etapa, pedido: movimento.pedido).nome
    numero = "##{movimento.pedido.uuid.first(8)}"
    return "voltou o #{numero} à ordem de chegada na #{etapa}" if movimento.voltou?

    "#{movimento.para < movimento.de ? "passou o #{numero} à frente" : "pôs o #{numero} mais atrás"} na #{etapa} (#{movimento.de}º → #{movimento.para}º)"
  end

  def efeito_do_movimento(movimento, pedido)
    if movimento.pedido_id == pedido.id
      return if movimento.voltou? || movimento.para > movimento.de

      "passou à frente de #{pluralize(movimento.de - movimento.para, "pedido", plural: "pedidos")}"
    elsif (empurrado = movimento.empurrado(pedido))
      para = empurrado["para"] ? momento_da_fila(Time.zone.parse(empurrado["para"])) : "sem previsão"
      "este pedido: #{momento_da_fila(Time.zone.parse(empurrado["de"]))} → #{para}"
    end
  end
end
