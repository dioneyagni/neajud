# An arte's Referência + Nome and the full name they make (Etapa 1.1, 5/5).
# The full name is computed, never stored — molde code, referência, nome,
# part, size, empty pieces skipped:
#   001-TNS_19_Bluey Azul_Lateral_29-30
# With accents on screen, without them in a downloaded file's name.
#
# Two artes with the same full name are the same arte uploaded twice: the
# page offers to make the newer a version of the older one. Until Etapa 1.2
# turns an arte into one file per size, the size is part of that key.
module NomeDeArte
  extend ActiveSupport::Concern

  included do
    belongs_to :referencia, optional: true
    atribui_por_uuid :referencia
    validate :referencia_do_mesmo_molde
  end

  # Usage: arte.nome_completo(para_arquivo: true) # => "001-TNS_19_Lingua_Lateral_29-30"
  def nome_completo(para_arquivo: false)
    return nil unless arte_com_molde?

    texto = [ molde.codigo, referencia&.nome, nome, resolved_peca&.nome, tamanho&.nome ].map(&:presence).compact.join("_")
    para_arquivo ? I18n.transliterate(texto).gsub(%r{[/\\:*?"<>|]}, "-") : texto
  end

  # Usage: arte.artes_com_mesmo_nome.first # => the arte uploaded before it, if any
  def artes_com_mesmo_nome
    return Arquivo.none unless arte_com_molde? && tamanho_id && nome.present?

    candidatas = Arquivo.ativos.where(category: "artes", molde_id: molde_id, referencia_id: referencia_id, tamanho_id: tamanho_id).where.not(id: id)
    Arquivo.where(id: candidatas.select { |outra| TextoComparavel.iguais?(outra.nome, nome) }.map(&:id)).order(:created_at)
  end

  # After the molde is chosen or changed: a referência of another molde is
  # dropped, and blanks are filled from the file name ("19-BLUEY PTO-LINGUA"
  # → referência 19, created in the molde if missing; nome "BLUEY PTO").
  # update_columns: a legacy arte that fails today's validations still gets it.
  # Usage: arte.ajustar_referencia_e_nome!
  def ajustar_referencia_e_nome!
    return unless category == "artes"

    self.referencia = nil if referencia && referencia.molde_id != molde_id
    preencher_pelo_nome_do_arquivo if molde
    update_columns(referencia_id: referencia_id, nome: nome) if referencia_id_changed? || nome_changed?
  end

  # Names already used in this arte's referência (or molde, without one), for
  # the Nome field's suggestions — each once, in its first-registered spelling.
  # Usage: arte.sugestoes_de_nome # => ["Bluey Azul", "Gato Preto"]
  def sugestoes_de_nome
    return [] unless molde_id

    Arquivo.ativos.where(category: "artes", molde_id: molde_id, referencia_id: referencia_id).where.not(nome: [ nil, "" ])
           .order(:id).pluck(:nome).uniq { |n| TextoComparavel.chave(n) }.sort
  end

  private

  def arte_com_molde?
    category == "artes" && molde.present?
  end

  def preencher_pelo_nome_do_arquivo
    lido = NomeDoArquivo.ler(filename, partes: Peca.pluck(:nome))
    self.referencia ||= Referencia.do_molde!(molde, lido[:referencia]) if lido[:referencia]
    self.nome = lido[:nome] if nome.blank?
  end

  def referencia_do_mesmo_molde
    return if referencia.nil? || referencia.molde_id == molde_id

    errors.add(:referencia, "#{referencia.nome.inspect} belongs to another molde; expected one of #{molde&.nome.inspect}")
  end
end
