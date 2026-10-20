require "yaml"

# Which E2E specs a set of changed files needs (decided 19/10/2026), from
# e2e/areas.yml: no E2E, the whole suite, or some areas' specs. Plain Ruby,
# no Rails: bin/e2e asks it before booting anything.
#
# Usage:
#   selecao = SelecaoDoE2e.new(areas: YAML.load_file("e2e/areas.yml"), ordem: %w[autenticacao pedidos …])
#   r = selecao.dos_alterados(["app/views/pedidos/_painel.html.erb"])
#   r.specs   # => ["autenticacao", "pedidos", "pedidos-pecas", …] (in ordem)
#   r.motivos # => ["app/views/pedidos/_painel.html.erb → calcado"]
class SelecaoDoE2e
  Resultado = Struct.new(:specs, :tudo, :motivos, keyword_init: true)
  class Invalida < StandardError; end

  OPCOES_DO_GLOB = File::FNM_PATHNAME | File::FNM_EXTGLOB | File::FNM_DOTMATCH

  def initialize(areas:, ordem:)
    @config = areas
    @ordem = ordem
    validar!
  end

  # The specs the changed files need; the whole suite when one of them is
  # global or belongs to no area.
  def dos_alterados(arquivos)
    motivos = []
    areas = []
    specs = []
    arquivos.each do |arquivo|
      destino = destino_de(arquivo)
      return tudo([ "#{arquivo} → #{destino}" ]) if %i[global sem_area].include?(destino)
      next if destino == :sem_e2e

      motivos << "#{arquivo} → #{Array(destino).join(", ")}"
      destino.is_a?(String) ? specs << destino : areas.concat(destino)
    end
    resultado((areas.uniq.flat_map { |a| specs_da_area(a) } + specs.flat_map { |s| expandir(s) }), motivos)
  end

  # One area's specs by its name.
  # Usage: selecao.da_area("tecido").specs # => ["autenticacao", "pedido-tecido", …]
  def da_area(nome)
    raise Invalida, "unknown area #{nome.inspect}; expected one of #{nomes_das_areas.join(", ")}" unless nomes_das_areas.include?(nome)

    resultado(specs_da_area(nome), [ "--area #{nome}" ])
  end

  private

  # :sem_e2e, :global, a spec name (an e2e/<name>.spec.js), the areas it
  # belongs to, or :sem_area.
  def destino_de(arquivo)
    return :sem_e2e if casa?(arquivo, @config["sem_e2e"])
    return :global if casa?(arquivo, @config["global"])

    spec = arquivo[%r{\Ae2e/([\w-]+)\.spec\.js\z}, 1]
    return spec if spec

    areas = @config["areas"].select { |_, area| casa?(arquivo, area["arquivos"]) }.keys
    areas.empty? ? :sem_area : areas
  end

  def casa?(arquivo, padroes)
    Array(padroes).any? { |padrao| File.fnmatch?(padrao, arquivo, OPCOES_DO_GLOB) }
  end

  def specs_da_area(nome)
    @config["areas"].fetch(nome)["specs"].flat_map { |s| expandir(s) }
  end

  # "bloco" and any spec inside it are the whole block.
  def expandir(spec)
    bloco = @config["bloco"]
    spec == "bloco" || bloco.include?(spec) ? bloco : [ spec ]
  end

  def resultado(specs, motivos)
    escolhidos = specs.empty? ? [] : (@config["sempre"] + specs)
    Resultado.new(specs: @ordem.select { |s| escolhidos.include?(s) }, tudo: false, motivos: motivos)
  end

  def tudo(motivos)
    Resultado.new(specs: @ordem, tudo: true, motivos: motivos)
  end

  def nomes_das_areas
    @config["areas"].keys
  end

  # Every listed spec belongs somewhere, and every name in the file is a spec.
  def validar!
    cobertos = @config["sempre"] + @config["bloco"] + @config["areas"].values.flat_map { |a| a["specs"] }
    sem_area = @ordem - cobertos
    raise Invalida, "specs in no area of e2e/areas.yml: #{sem_area.join(", ")}; add each to an area" if sem_area.any?

    desconhecidos = cobertos.uniq - @ordem - [ "bloco" ]
    raise Invalida, "e2e/areas.yml names specs not in E2E_SPECS: #{desconhecidos.join(", ")}" if desconhecidos.any?
  end
end
