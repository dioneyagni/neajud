# The production stages of each pedido type, from config/etapas_producao.yml
# (Etapa 2.2, 2/3; decided 07/10/2026). Read once and checked: a wrong value
# raises naming it and what was expected, so a typo never silently changes
# what the factory may do.
#
# Usage: EtapasProducao.do_tipo("calcado").map(&:chave) # => ["impressao", "corte", "estamparia", "conferencia"]
#        EtapasProducao.etapa("calcado", "estamparia").trava # => ["impressao", "corte"]
class EtapasProducao
  ARQUIVO = Rails.root.join("config", "etapas_producao.yml")
  MEDIDAS = %w[metragem quantidade].freeze
  ESPERADOS = %w[papel tecido pecas].freeze
  LINHAS = %w[impressao corte].freeze
  NIVEIS = %w[linha referencia pedido].freeze

  Etapa = Struct.new(:chave, :nome, :medida, :esperado, :linhas, :niveis, :trava, :reposicao, keyword_init: true) do
    def metragem?
      medida == "metragem"
    end
  end

  class Invalida < StandardError; end

  def self.do_tipo(tipo)
    todas.fetch(tipo.to_s) { raise Invalida, "no production stages for pedido type #{tipo.inspect}; expected one of #{todas.keys.join(", ")}" }
  end

  # Raises when the stage doesn't exist for the type.
  def self.etapa(tipo, chave)
    do_tipo(tipo).find { |e| e.chave == chave.to_s } ||
      raise(Invalida, "unknown production stage #{chave.inspect} for #{tipo}; expected one of #{do_tipo(tipo).map(&:chave).join(", ")}")
  end

  def self.todas
    @todas ||= ler(YAML.safe_load_file(ARQUIVO))
  end

  def self.ler(conteudo)
    conteudo.to_h { |tipo, etapas| [ tipo, etapas.map { |dados| etapa_de(tipo, dados, etapas.map { |e| e["chave"] }) } ] }
  end

  def self.etapa_de(tipo, dados, chaves)
    etapa = Etapa.new(**dados.symbolize_keys.slice(*Etapa.members), trava: Array(dados["trava"]), reposicao: dados["reposicao"] == true)
    erros = erros_da(etapa, chaves)
    raise Invalida, "#{tipo}/#{etapa.chave}: #{erros.join("; ")}" if erros.any?

    etapa
  end

  def self.erros_da(etapa, chaves)
    { medida: MEDIDAS, esperado: ESPERADOS, linhas: LINHAS }.filter_map { |campo, validos| "#{campo} #{etapa[campo].inspect} is not one of #{validos.join(", ")}" unless validos.include?(etapa[campo]) } +
      (Array(etapa.niveis) - NIVEIS).map { |nivel| "nivel #{nivel.inspect} is not one of #{NIVEIS.join(", ")}" } +
      (etapa.trava - chaves).map { |outra| "trava #{outra.inspect} is not a stage of this type" } +
      (etapa.reposicao && etapa.medida != "quantidade" ? [ "reposicao needs medida quantidade (it counts missing pieces)" ] : [])
  end
  private_class_method :ler, :etapa_de, :erros_da
end
