# Piloto or production (Etapa 1.2, 2/3 parte 2b; decided 05/10/2026). Each
# part of an arte has one piloto — the editable, heavy master file — and its
# grade of production files, the light ones used day to day.
#
# - The piloto is in the approval's photo like any file: a new version of it
#   undoes the approval (changing the piloto must change the production).
# - Production files made before the piloto's newest version are marked
#   "before the current piloto" until they get a new version themselves.
# - The pedido (Etapa 1.2, 3/3) uses production; the piloto only covers a
#   sample — an arte asked only in the piloto's size with no production file
#   for it.
module PapelNaArte
  extend ActiveSupport::Concern

  PAPEIS = %w[producao piloto].freeze

  included do
    validates :papel, inclusion: { in: PAPEIS, message: "%{value} is not a role; expected producao or piloto" }
    validate :um_piloto_por_parte, if: :piloto?
    validate :piloto_so_no_calcado, if: :piloto?
  end

  def piloto?
    papel == "piloto"
  end

  # The other file that is the piloto of this file's part, if any.
  # Usage: arquivo.piloto_da_parte&.filename # => "20-BLUEY AZUL"
  def piloto_da_parte
    return nil unless arte_id

    Arquivo.ativos.where(arte_id: arte_id, papel: "piloto").where.not(id: id).find { |piloto| piloto.resolved_peca == resolved_peca }
  end

  # Makes this file its part's piloto; the previous one goes back to
  # production. Returns that previous piloto, or nil.
  # Usage: anterior = arquivo.tornar_piloto!
  def tornar_piloto!
    transaction do
      anterior = piloto_da_parte
      anterior&.update!(papel: "producao")
      update!(papel: "piloto")
      anterior
    end
  end

  # Usage: arquivo.voltar_para_producao!
  def voltar_para_producao!
    update!(papel: "producao")
  end

  # A production file made before its part's piloto got its newest version
  # (v2 on): it still carries the old drawing.
  # Usage: arquivo.anterior_ao_piloto? # => true
  def anterior_ao_piloto?
    return false if piloto? || approved_version.nil?

    versao_do_piloto = piloto_da_parte&.approved_version
    versao_do_piloto.present? && versao_do_piloto.version_number > 1 && approved_version.created_at < versao_do_piloto.created_at
  end

  private

  # Etapa 2.5c: each file of a work without corte is already the editable one.
  def piloto_so_no_calcado
    errors.add(:papel, "can't be piloto: #{arte.rotulo_do_tipo} has no piloto, each of its files is the editable one") if arte && !arte.usa_pecas?
  end

  def um_piloto_por_parte
    outro = piloto_da_parte
    return unless outro

    errors.add(:papel, "#{outro.filename.inspect} is already the piloto of #{resolved_peca&.nome || "this arte's files without a part"}; expected one piloto per part")
  end
end
