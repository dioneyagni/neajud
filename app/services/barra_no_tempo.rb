# One pedido's bar on the Linha do tempo (Painel 2/4c): from its start to
# its previsão, or to its delivery. Its pieces come as [left, width] in % of
# the window, clipped to it (nil when outside):
#
#   feito    — start to now (in production)
#   previsto — now to the previsão, up to the end of the deadline's day
#   atraso   — what falls after the deadline
#   espera   — start to now, without previsão (dashed)
#   se_confirmar — a draft's "se confirmar agora", now to that previsão
#   entregue — start to the delivery
#
# The original and its reposições are one bar: it ends when the last of
# them does, and has no previsão while one of them has none.
#
# Usage: barra = BarraNoTempo.new(linha, Time.current, Date.current - 2, Date.current + 12)
#        [ barra.grupo, barra.feito, barra.atraso ] # => ["em_producao", [14.3, 2.1], [40.0, 7.5]]
class BarraNoTempo
  attr_reader :linha

  # The moment's place in the window, in %; nil outside it.
  def self.posicao(momento, de, ate)
    inicio, fim = de.in_time_zone, ate.in_time_zone
    return unless momento && momento >= inicio && momento <= fim

    ((momento - inicio) / (fim - inicio) * 100).round(2)
  end

  def initialize(linha, agora, de, ate)
    @linha, @agora = linha, agora
    @de, @ate = de, ate
    @janela = de.in_time_zone..ate.in_time_zone
  end

  def grupo
    @grupo ||= if linha.pedido.status == "entregue" then "entregues"
    elsif linha.previsao.nil? || linha.previsao.se_confirmar then "pendentes"
    elsif pronta? || fim_do_par then "em_producao"
    else "sem_previsao"
    end
  end

  def inicio
    linha.inicio || linha.chegada
  end

  # Its previsão (the pair's), its delivery; now when only the delivery is left.
  def fim
    @fim ||= case grupo
    when "entregues" then linha.pedido.entregue_em
    when "pendentes" then linha.previsao&.fim
    when "em_producao" then pronta? ? @agora : fim_do_par
    end
  end

  # Every stage done, its reposições' too: only the delivery is left.
  def pronta?
    linha.com_reposicoes.all? { |l| l.previsao&.pronta? }
  end

  # The previsão that says why there is none: its own, or a reposição's.
  def sem_previsao
    return linha.previsao if grupo == "pendentes"

    linha.com_reposicoes.filter_map(&:previsao).find { |previsao| previsao.fim.nil? && !previsao.pronta? }
  end

  # The end of the deadline's day.
  def prazo_fim
    linha.prazo && (linha.prazo + 1).in_time_zone
  end

  # Days past the deadline (nil when on time).
  def dias_de_atraso
    return unless prazo_fim && fim && fim > prazo_fim

    (fim.to_date - linha.prazo).to_i
  end

  def na_janela?
    return @janela.cover?(@agora) if %w[sem_previsao pendentes].include?(grupo)

    inicio < @janela.end && (fim || @agora) > @janela.begin
  end

  def comecou_antes?
    inicio < @janela.begin
  end

  def feito
    grupo == "em_producao" && pedaco(inicio, [ @agora, fim ].min)
  end

  def previsto
    grupo == "em_producao" && pedaco([ @agora, inicio ].max, [ fim, prazo_fim ].compact.min)
  end

  def atraso
    dias_de_atraso && grupo == "em_producao" && pedaco([ prazo_fim, @agora, inicio ].max, fim)
  end

  def espera
    (grupo == "sem_previsao" || (grupo == "pendentes" && fim.nil?)) && pedaco(inicio, @agora)
  end

  def se_confirmar
    grupo == "pendentes" && fim && pedaco(@agora, fim)
  end

  def entregue
    grupo == "entregues" && pedaco(inicio, fim)
  end

  def prazo_em
    self.class.posicao(prazo_fim, @de, @ate)
  end

  # Where its label goes: after the bar and the deadline, in %.
  def fim_em
    momento = [ fim || @agora, prazo_fim ].compact.max
    momento = [ [ momento, @janela.begin ].max, @janela.end ].min
    self.class.posicao(momento, @de, @ate)
  end

  private

  # The pair's last stage end; nil while one of them has no previsão.
  def fim_do_par
    previsoes = linha.com_reposicoes.filter_map(&:previsao).reject(&:pronta?)
    return if previsoes.empty? || previsoes.any? { |previsao| previsao.fim.nil? }

    previsoes.map(&:fim).max
  end

  def pedaco(de, ate)
    return unless de && ate

    de, ate = [ de, @janela.begin ].max, [ ate, @janela.end ].min
    return if ate <= de

    esquerda = self.class.posicao(de, @de, @ate)
    [ esquerda, (self.class.posicao(ate, @de, @ate) - esquerda).round(2) ]
  end
end
