# What a machine may do (Máquinas 1/5, decided 20/11/2026, Q2a): a fixed
# list, each trabalho the type × stage pairs it serves. A machine that does
# one of them gives its speed in it; the stages' informado is then the sum
# of their machines (RitmoProducao#informado). The same speed for every
# arte (Q2a: a slower mode per arte is another idea). The Conferência is
# done by people: no trabalho, only Ritmos.
#
# Usage: TrabalhosDeMaquina.da_etapa("tecido", "dublagem_final").chave # => "dublagem"
#        TrabalhosDeMaquina.trabalho("calandra").unidade              # => "m/h"
class TrabalhosDeMaquina
  # chave, nome, detalhe (what the page adds to the name), etapas [[tipo, etapa]].
  # The Corte do calçado is its cutting machine's parameters, not a speed.
  Trabalho = Struct.new(:chave, :nome, :detalhe, :etapas, keyword_init: true) do
    def corte_por_parametros?
      chave == CORTE_POR_PARAMETROS
    end

    # In the first stage's rhythm unit ("m/h", "unidades/h"; the
    # Estamparia's paper "m/h"). nil for the Corte do calçado.
    def unidade
      return if corte_por_parametros?

      tipo, etapa = etapas.first
      RitmoProducao.new(tipo: tipo, etapa: etapa).unidade
    end
  end

  CORTE_POR_PARAMETROS = "corte_calcado"

  TODOS = [
    Trabalho.new(chave: "impressao_papel", nome: "Impressão em papel", detalhe: "calçado e tecido", etapas: [ %w[calcado impressao], %w[tecido impressao] ]),
    Trabalho.new(chave: "impressao_dtf", nome: "Impressão DTF", etapas: [ %w[dtf impressao] ]),
    Trabalho.new(chave: CORTE_POR_PARAMETROS, nome: "Corte do calçado", detalhe: "pelos parâmetros da máquina de corte", etapas: [ %w[calcado corte] ]),
    Trabalho.new(chave: "corte_dtf", nome: "Corte do DTF", etapas: [ %w[dtf corte] ]),
    Trabalho.new(chave: "estamparia", nome: "Estamparia", detalhe: "calçado", etapas: [ %w[calcado estamparia] ]),
    Trabalho.new(chave: "calandra", nome: "Calandra", detalhe: "tecido", etapas: [ %w[tecido calandra] ]),
    Trabalho.new(chave: "dublagem", nome: "Dublagem", detalhe: "e Dublagem final", etapas: [ %w[tecido dublagem], %w[tecido dublagem_final] ])
  ].freeze

  POR_CHAVE = TODOS.index_by(&:chave).freeze
  POR_ETAPA = TODOS.flat_map { |trabalho| trabalho.etapas.map { |etapa| [ etapa, trabalho ] } }.to_h.freeze

  def self.todos = TODOS

  def self.chaves = POR_CHAVE.keys

  # Usage: TrabalhosDeMaquina.trabalho("calandra")
  def self.trabalho(chave)
    POR_CHAVE.fetch(chave.to_s) { raise ArgumentError, "Unknown machine trabalho #{chave.inspect}; expected one of #{chaves.join(", ")}" }
  end

  # nil for a stage no machine does (the Conferência).
  def self.da_etapa(tipo, etapa)
    POR_ETAPA[[ tipo.to_s, etapa.to_s ]]
  end
end
