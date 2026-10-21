# The production stages of each pedido type, from config/etapas_producao.yml
# (Etapa 2.2, 2/3; decided 07/10/2026). Read once and checked: a wrong value
# raises naming it and what was expected, so a typo never silently changes
# what the factory may do.
#
# Usage: EtapasProducao.do_tipo("calcado").map(&:chave) # => ["impressao", "corte", "estamparia", "conferencia"]
#        EtapasProducao.etapa("calcado", "estamparia").trava # => ["impressao", "corte"]
#        EtapasProducao.do_tipo("dtf", pedido: pedido_em_rolo).map(&:chave) # => ["impressao"]
class EtapasProducao
  ARQUIVO = Rails.root.join("config", "etapas_producao.yml")
  MEDIDAS = %w[metragem quantidade].freeze
  ESPERADOS = %w[papel tecido pecas filme metros].freeze
  LINHAS = %w[impressao corte dtf tecido].freeze
  NIVEIS = %w[linha referencia pedido].freeze
  # What a metragem stage takes from the stock (Etapa 2.3e): the pedido's
  # paper or film, or each line's fabric.
  MATERIAIS = %w[impressao linha].freeze
  # What a stage's `quando` may ask of the pedido (Etapa 2.6b2, decided
  # 15/10/2026: the DTF's Corte only when it is delivered cut).
  QUANDO = { "entrega" => Pedido::ENTREGAS }.freeze

  Etapa = Struct.new(:chave, :nome, :medida, :esperado, :linhas, :niveis, :trava, :reposicao, :quando, :unidade, :material, keyword_init: true) do
    def metragem?
      medida == "metragem"
    end

    # What its measure is counted in: "m", else the YAML's unidade ("peças").
    # Does its baixa adjust the stock (Etapa 2.3e)?
    def ajusta_estoque?
      material.present?
    end

    def unidade_da_medida
      metragem? ? "m" : (unidade || "peças")
    end

    # Usage: etapa.vale_para?(pedido) # => false for the DTF's Corte on the roll
    def vale_para?(pedido)
      Array(quando).all? { |campo, valor| pedido.public_send(campo).to_s == valor.to_s }
    end
  end

  class Invalida < StandardError; end

  # A pedido given leaves out the stages it doesn't go through (`quando`).
  def self.do_tipo(tipo, pedido: nil)
    etapas = todas.fetch(tipo.to_s) { raise Invalida, "no production stages for pedido type #{tipo.inspect}; expected one of #{todas.keys.join(", ")}" }
    pedido ? etapas.select { |etapa| etapa.vale_para?(pedido) } : etapas
  end

  # Raises when the stage doesn't exist for the type (or that pedido).
  def self.etapa(tipo, chave, pedido: nil)
    do_tipo(tipo, pedido: pedido).find { |e| e.chave == chave.to_s } ||
      raise(Invalida, "unknown production stage #{chave.inspect} for #{tipo}#{" (this pedido)" if pedido}; expected one of #{do_tipo(tipo, pedido: pedido).map(&:chave).join(", ")}")
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
      (etapa.reposicao && etapa.medida != "quantidade" ? [ "reposicao needs medida quantidade (it counts missing pieces)" ] : []) +
      erros_do_material(etapa) +
      erros_do_quando(etapa.quando)
  end

  def self.erros_do_quando(quando)
    return [] if quando.nil?
    return [ "quando #{quando.inspect} is not a map like { entrega: cortada }" ] unless quando.is_a?(Hash)

    quando.filter_map do |campo, valor|
      next "quando #{campo.inspect} is not one of #{QUANDO.keys.join(", ")}" unless QUANDO.key?(campo)

      "quando #{campo} #{valor.inspect} is not one of #{QUANDO[campo].join(", ")}" unless QUANDO[campo].include?(valor)
    end
  end
  def self.erros_do_material(etapa)
    return [] if etapa.material.nil?
    return [ "material #{etapa.material.inspect} is not one of #{MATERIAIS.join(", ")}" ] unless MATERIAIS.include?(etapa.material)

    etapa.metragem? ? [] : [ "material needs medida metragem (the stock is kept in meters)" ]
  end
  private_class_method :ler, :etapa_de, :erros_da, :erros_do_quando, :erros_do_material
end
