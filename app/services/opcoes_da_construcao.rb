# What each layer of a construção may be (Dublagem 3/5, decided
# 30/10-02/11/2026): a superfície from the tecidos whose group goes on the
# face; under a layer, the tecidos whose group is a base and dubs with it in
# config/dublagens.yml; between them, the registered ligantes the network
# allows in the situação (decision 4). The construção's form lists these, and
# RegrasDaConstrucao checks a saved one against the same answers.
#
# Usage: opcoes = OpcoesDaConstrucao.new(visiveis(MateriaPrima))
#        opcoes.bases_sob(construcao.superficie).map(&:nome_completo) # => ["Espuma TC4 3 mm-Branco-1.40 m", …]
class OpcoesDaConstrucao
  # materiais: the visible MateriaPrima scope.
  def initialize(materiais)
    @materiais = materiais
  end

  def superficies
    tecidos.select { |material| material.grupo_material.superficie }
  end

  # The bases that dub under a layer; none while it has no material.
  def bases_sob(camada_acima)
    return [] unless camada_acima&.materia_prima

    tecidos.select { |material| material.grupo_material.base && ligacao(camada_acima, material) }
  end

  # The network's ligação between a layer and the material under it — the
  # superfície's lado first; nil when they don't dub.
  # Usage: opcoes.ligacao(superficie, lona).dubla # => "antes"
  def ligacao(camada_acima, material_abaixo)
    lado = camada_acima.lado if camada_acima.superficie?
    RedeDeDublagens.ligacao(camada_acima.materia_prima.grupo_material.nome, material_abaixo.grupo_material.nome, lado: lado)
  end

  # The registered ligantes that serve a ligação in a situação (nil = normal).
  # Usage: opcoes.ligantes(ligacao, "vai_frequencia").map(&:micras) # => [35]
  def ligantes(ligacao, situacao)
    permitidos = ligacao.ligantes_na(situacao)
    ligantes_cadastrados.select { |material| permitidos.any? { |ligante| ligante.serve?(material) } }
  end

  private

  def tecidos
    @tecidos ||= ordenados(@materiais.tecidos)
  end

  def ligantes_cadastrados
    @ligantes_cadastrados ||= ordenados(@materiais.ligantes)
  end

  def ordenados(escopo)
    escopo.includes(:grupo_material, :cor_material).to_a.sort_by(&:nome_completo)
  end
end
