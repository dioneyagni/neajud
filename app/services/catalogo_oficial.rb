# Loads the official Neajud catalog (config/catalogo_oficial.yml) into the
# database — Etapa 1.1, 3/5. Safe to run again and again: records are matched
# by the fixed uuid in the file, so names, abbreviations and grades update in
# place; what left the file goes to the trash (never deleted, moldes may use
# it) and comes back if listed again.
#
# A record not found by uuid but with the same name (a development sample
# created by hand before the list existed, e.g. "Jogging") is adopted: it
# takes the official uuid, so the moldes that use it stay linked.
#
# Usage: CatalogoOficial.sincronizar! # => { produtos: 3, modelos: 9, na_lixeira: 1 }
class CatalogoOficial
  CAMINHO = Rails.root.join("config/catalogo_oficial.yml")
  # Written to exclusao_logs.changed_by: nobody deleted these, the list did.
  AUTORIA = "catalogo_oficial".freeze

  class ListaInvalida < StandardError; end

  def self.sincronizar!(caminho: CAMINHO)
    new(YAML.safe_load_file(caminho)).sincronizar!
  end

  def initialize(lista)
    @produtos = Array(lista&.fetch("produtos", nil))
    raise ListaInvalida, "Expected a \"produtos:\" list in the official catalog; got #{lista.inspect[0, 200]}" if @produtos.empty?
  end

  def sincronizar!
    ActiveRecord::Base.transaction do
      @produtos.each { |dados| sincronizar_produto(dados) }
      na_lixeira = excluir_fora_da_lista(Produto, uuids_de(@produtos)) + excluir_fora_da_lista(Modelo, uuids_de(modelos_listados))
      { produtos: @produtos.size, modelos: modelos_listados.size, na_lixeira: na_lixeira }
    end
  end

  private

  def sincronizar_produto(dados)
    produto = gravar(Produto, dados, grade: expandir_grade(dados))
    Array(dados["modelos"]).each do |modelo|
      gravar(Modelo, modelo, abreviacao: exigir(modelo, "abreviacao"), produto: produto)
    end
  end

  def gravar(classe, dados, **atributos)
    uuid = exigir(dados, "uuid")
    nome = exigir(dados, "nome")
    registro = classe.find_by(uuid: uuid) || adotar_por_nome(classe, nome) || classe.new
    registro.update!(uuid: uuid, nome: nome, **atributos)
    registro.restaurar!(changed_by: AUTORIA) if registro.excluido?
    registro
  end

  # Only a record whose uuid isn't in the list can be adopted.
  def adotar_por_nome(classe, nome)
    classe.where("LOWER(nome) = ?", nome.downcase).where.not(uuid: todos_os_uuids).first
  end

  def excluir_fora_da_lista(classe, uuids)
    fora = classe.ativos.where.not(uuid: uuids).to_a
    fora.each { |registro| registro.excluir!(changed_by: AUTORIA) }
    fora.size
  end

  # { de: 18, ate: 46 } → "18".."46"; a list stays a list (of strings).
  def expandir_grade(dados)
    grade = dados.fetch("grade", [])
    return (grade.fetch("de")..grade.fetch("ate")).map(&:to_s) if grade.is_a?(Hash)
    return grade.map(&:to_s) if grade.is_a?(Array)

    raise ListaInvalida, "grade of #{dados["nome"].inspect} must be a list or { de:, ate: }; got #{grade.inspect}"
  end

  def exigir(dados, chave)
    valor = dados[chave].to_s.strip
    raise ListaInvalida, "Missing #{chave.inspect} in official catalog entry #{dados.inspect}" if valor.empty?

    valor
  end

  def modelos_listados
    @modelos_listados ||= @produtos.flat_map { |p| Array(p["modelos"]) }
  end

  def uuids_de(entradas)
    entradas.map { |e| e["uuid"].to_s }
  end

  def todos_os_uuids
    @todos_os_uuids ||= uuids_de(@produtos) + uuids_de(modelos_listados)
  end
end
