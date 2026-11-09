# Adds the initial dublagem network to the database (rede editável 1/2,
# decided 09/11/2026, Q8a) from db/seeds/rede_de_dublagens.yml. Only adds: a
# situação (by chave), a ligação (its pair in either order, with the same
# lado) or a group (by name) already there is never changed — the team edits
# the network in the app. A group the file names and the database lacks is
# created with the file's roles and asking what a group made in Materiais
# asks (gramatura). The file is checked
# first: a wrong value raises naming it and what was expected, and nothing is
# written.
#
# Usage: ImportarRedeDeDublagens.new.call
#        # => { criados: ["Situação tecido_molha", "Oxford", "Oxford–Lona", …], existentes: ["Oxford–Oxford", …] }
class ImportarRedeDeDublagens
  ARQUIVO = Rails.root.join("db", "seeds", "rede_de_dublagens.yml")

  class Invalida < StandardError; end

  # conteudo: the file as a Hash (a spec gives its own).
  def initialize(conteudo: YAML.safe_load_file(ARQUIVO))
    @conteudo = conteudo
    @relatorio = { criados: [], existentes: [] }
  end

  def call
    rede = LeituraDaRedeInicial.new(@conteudo).call
    ActiveRecord::Base.transaction do
      situacoes = rede[:situacoes].to_h { |chave, nome| [ chave, situacao(chave, nome) ] }
      rede[:ligacoes].each { |ligacao| importar_ligacao(ligacao, situacoes, rede[:grupos]) }
    end
    RedeDeDublagens.esquecer
    @relatorio
  end

  private

  def situacao(chave, nome)
    existente = SituacaoDublagem.find_by(chave: chave)
    return anotar(:existentes, "Situação #{chave}", existente) if existente

    anotar(:criados, "Situação #{chave}", SituacaoDublagem.create!(chave: chave, nome: nome))
  end

  def importar_ligacao(ligacao, situacoes, papeis)
    grupo_a, grupo_b = ligacao.par.map { |nome| grupo(nome, papeis) }
    nome = "#{grupo_a.nome}–#{grupo_b.nome}#{" (#{ligacao.lado})" if ligacao.lado}"
    return anotar(:existentes, nome, nil) if LigacaoDublagem.do_par(grupo_a, grupo_b).exists?(lado: ligacao.lado)

    registro = LigacaoDublagem.create!(grupo_a: grupo_a, grupo_b: grupo_b, lado: ligacao.lado, dubla: ligacao.dubla, a_confirmar: ligacao.a_confirmar)
    ligantes = ligacao.ligantes.map { |ligante| [ ligante, nil ] } +
               ligacao.situacoes.flat_map { |chave, lista| lista.map { |ligante| [ ligante, situacoes.fetch(chave) ] } }
    ligantes.each.with_index(1) { |(ligante, situacao), posicao| criar_ligante(registro, ligante, situacao, posicao, papeis) }
    anotar(:criados, nome, registro)
  end

  def criar_ligante(ligacao, ligante, situacao, posicao, papeis)
    ligacao.ligantes.create!(grupo_material: grupo(ligante.grupo, papeis), situacao_dublagem: situacao, posicao: posicao,
                             micras: ligante.micras, micras_minimo: ligante.minimo)
  end

  def grupo(nome, papeis)
    existente = GrupoMaterial.where("LOWER(nome) = ?", nome.downcase).first
    return existente if existente

    dados = papeis[nome] || raise(Invalida, "group #{nome.inspect} is not registered and not in grupos:; expected its roles there (#{LeituraDaRedeInicial::PAPEIS.join(", ")})")
    anotar(:criados, nome, GrupoMaterial.create!(nome: nome, **dados.symbolize_keys))
  end

  def anotar(lista, nome, registro)
    @relatorio[lista] << nome
    registro
  end
end
