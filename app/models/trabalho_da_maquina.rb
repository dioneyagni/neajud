# One trabalho a machine does (Máquinas 1/5, decided 20/11/2026): its speed
# per hour in the trabalho's unit — or, for the Corte do calçado, its
# cutting machine's parameters (Q8a; blank = the default). Unchecked on the
# machine's page, the row is removed: the machine's histórico keeps what it
# was ("tirou Dublagem").
#
# Usage: TrabalhoDaMaquina.ativos.where(trabalho: "calandra").sum(:por_hora) # => 80
class TrabalhoDaMaquina < ApplicationRecord
  self.table_name = "trabalhos_da_maquina"

  include GeraUuid
  include ParametrosDoCorte

  belongs_to :maquina, inverse_of: :trabalhos

  validates :trabalho, inclusion: { in: TrabalhosDeMaquina.chaves, message: "%{value} is not a machine trabalho" }
  validates :por_hora, numericality: { greater_than: 0, message: "precisa ser mais que 0" }, unless: :corte_por_parametros?

  # The trabalhos of the machines not in the trash.
  scope :ativos, -> { joins(:maquina).merge(Maquina.ativos) }

  def tipo_de_trabalho
    TrabalhosDeMaquina.trabalho(trabalho)
  end

  def corte_por_parametros?
    trabalho == TrabalhosDeMaquina::CORTE_POR_PARAMETROS
  end

  # What it does, as the list's chip and the histórico say it.
  # Usage: trabalho.velocidade # => "40 m/h"; the Corte do calçado's "faca 120 mm/s, os outros no padrão"
  def velocidade
    return "#{numero(por_hora)} #{tipo_de_trabalho.unidade}" unless corte_por_parametros?

    digitados = parametros_digitados.map { |campo, valor| "#{ParametrosDoCorte::ROTULOS[campo][0].downcase} #{numero(valor)} #{ParametrosDoCorte::ROTULOS[campo][1]}" }
    return "no padrão" if digitados.empty?

    [ digitados.to_sentence(words_connector: ", ", last_word_connector: " e ", two_words_connector: " e "), ("os outros no padrão" if digitados.size < ParametrosDoCorte::PADRAO.size) ].compact.join(", ")
  end

  # Usage: trabalho.descricao # => "Calandra 40 m/h"; "Corte do calçado (no padrão)"
  def descricao
    corte_por_parametros? ? "#{tipo_de_trabalho.nome} (#{velocidade})" : "#{tipo_de_trabalho.nome} #{velocidade}"
  end

  # The parameters typed (the rest is the default).
  # Usage: trabalho.parametros_digitados # => { velocidade_mm_s: 120.0 }
  def parametros_digitados
    ParametrosDoCorte::PADRAO.keys.filter_map { |campo| [ campo, self[campo].to_f ] if self[campo] }.to_h
  end

  private

  def numero(valor)
    ActiveSupport::NumberHelper.number_to_rounded(valor, precision: 3, separator: ",", strip_insignificant_zeros: true)
  end
end
