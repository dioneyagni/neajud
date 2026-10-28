require Rails.root.join("db/seeds/desenvolvimento").to_s

# Adds the development database's starting groups and materials
# (db/seeds/desenvolvimento.rb; decided 28/10/2026). Only adds: a group,
# color or material already there — found by name, or by the attributes that
# identify a material — is never changed, since the dev database holds real
# data. Refuses any environment but development.
#
# Usage: SemeadorDeDesenvolvimento.new.call
#        # => { criados: ["Lona", "Lona-Bege-1.40 m-300g", …], existentes: ["Oxford", …] }
class SemeadorDeDesenvolvimento
  class AmbienteErrado < StandardError; end

  def initialize(ambiente: Rails.env, grupos: DadosDeDesenvolvimento::GRUPOS, materiais: DadosDeDesenvolvimento::MATERIAIS)
    @ambiente = ambiente.to_s
    @grupos = grupos
    @materiais = materiais
    @relatorio = { criados: [], existentes: [] }
  end

  def call
    raise AmbienteErrado, "dev:semear only runs in development; this is #{@ambiente.inspect}" unless @ambiente == "development"

    ActiveRecord::Base.transaction do
      @grupos.each { |dados| semear_grupo(dados) }
      @materiais.each { |dados| semear_material(dados) }
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
    return anotar(:existentes, existente.nome_completo) if existente

    material = MateriaPrima.create!(identidade.merge(tipo: dados.fetch(:tipo, "tecido")))
    anotar(:criados, material.nome_completo)
  end

  # The attributes MateriaPrima's uniqueness checks; the absent ones are
  # blank gramatura or nil, as the stock entry saves them.
  def identidade_do_material(dados)
    {
      grupo_material: GrupoMaterial.where("LOWER(nome) = ?", dados[:grupo].downcase).first!,
      cor_material: CorMaterial.where("LOWER(nome) = ?", dados[:cor].downcase).first || CorMaterial.create!(nome: dados[:cor]),
      largura: dados[:largura], gramatura: dados[:gramatura].to_s,
      densidade: dados[:densidade], espessura_mm: dados[:espessura_mm], micras: dados[:micras], fornecedor: nil
    }
  end

  def anotar(lista, nome)
    @relatorio[lista] << nome
  end
end
