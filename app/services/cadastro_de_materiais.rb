# Adds groups and materials, never changing one that exists — found by name,
# or by the attributes that identify a material (decided 28/10/2026 for the
# dev seeds; shared since Primeiros passos 2/6a with the wizard's last step).
# Each material comes with no stock and no price.
#
# grupos: [{ nome:, superficie:, base:, estampavel:, ressalva:, pede:, obrigatorios: }]
# materiais: { chave => { grupo:, cor:, largura:, gramatura:, micras:, … tipo: } } (or an Array)
#
# Usage: r = CadastroDeMateriais.new(grupos: g, materiais: { "papel" => {…} }).call
#        r[:criados] # => ["Papel", "Papel-Branco-1.60 m-90g"]; r[:materiais]["papel"] # => the MateriaPrima
class CadastroDeMateriais
  def initialize(grupos:, materiais:)
    @grupos = grupos
    @materiais = materiais.is_a?(Hash) ? materiais : materiais.each_with_index.to_h { |dados, i| [ i, dados ] }
    @relatorio = { criados: [], existentes: [], materiais: {} }
  end

  # The material already registered for these attributes, or nil — without
  # creating its group or color (the wizard shows it as done).
  # Usage: CadastroDeMateriais.existente(grupo: "Papel", cor: "Branco", largura: "1.60 m", gramatura: "90g")
  def self.existente(dados)
    grupo = GrupoMaterial.where("LOWER(nome) = ?", dados[:grupo].downcase).first
    cor = CorMaterial.where("LOWER(nome) = ?", dados[:cor].downcase).first
    return unless grupo && cor

    MateriaPrima.find_by(identidade(dados, grupo, cor))
  end

  # The attributes MateriaPrima's uniqueness checks; the absent ones are
  # blank gramatura or nil, as the stock entry saves them.
  def self.identidade(dados, grupo, cor)
    { grupo_material: grupo, cor_material: cor, largura: dados[:largura], gramatura: dados[:gramatura].to_s,
      densidade: dados[:densidade], espessura_mm: dados[:espessura_mm], micras: dados[:micras], fornecedor: nil }
  end

  def call
    ActiveRecord::Base.transaction do
      @grupos.each { |dados| semear_grupo(dados) }
      @materiais.each { |chave, dados| @relatorio[:materiais][chave] = semear_material(dados) }
    end
    @relatorio
  end

  private

  def semear_grupo(dados)
    return anotar(:existentes, dados[:nome]) if GrupoMaterial.where("LOWER(nome) = ?", dados[:nome].downcase).exists?

    grupo = GrupoMaterial.new(dados.slice(:nome, :superficie, :base, :estampavel, :ressalva))
    grupo.definir_atributos(pede: dados[:pede], obrigatorios: dados[:obrigatorios])
    grupo.save!
    anotar(:criados, grupo.nome)
  end

  def semear_material(dados)
    identidade = identidade_do_material(dados)
    existente = MateriaPrima.find_by(identidade)
    return existente.tap { anotar(:existentes, existente.nome_completo) } if existente

    MateriaPrima.create!(identidade.merge(tipo: dados.fetch(:tipo, "tecido").to_s)).tap { |material| anotar(:criados, material.nome_completo) }
  end

  def identidade_do_material(dados)
    grupo = GrupoMaterial.where("LOWER(nome) = ?", dados[:grupo].downcase).first!
    cor = CorMaterial.where("LOWER(nome) = ?", dados[:cor].downcase).first || CorMaterial.create!(nome: dados[:cor])
    self.class.identidade(dados, grupo, cor)
  end

  def anotar(lista, nome)
    @relatorio[lista] << nome
  end
end
