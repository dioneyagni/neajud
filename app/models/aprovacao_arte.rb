# A client's approval of one version of an arte, registered by the team
# ("Aprovação registrada por [nome], cliente aprovou por [canal]" —
# docs/plano.md). It never blocks production; the pedido only shows it.
# A new version starts "aguardando" again: approvals are per version.
# Cancelled by mistake → cancelada_em (kept in the history, never deleted).
class AprovacaoArte < ApplicationRecord
  self.table_name = "aprovacoes_arte"

  include GeraUuid
  include ReferenciaAtiva

  CANAIS = {
    "whatsapp" => "WhatsApp", "email" => "E-mail", "telefone" => "Telefone",
    "presencial" => "Presencial", "outro" => "Outro"
  }.freeze

  belongs_to :arquivo
  belongs_to :arquivo_version
  belongs_to :user
  belongs_to :cancelada_por, class_name: "User", optional: true
  recusa_excluido :arquivo

  scope :validas, -> { where(cancelada_em: nil) }
  scope :recentes, -> { order(aprovado_em: :desc, id: :desc) }

  validates :canal, inclusion: { in: CANAIS.keys, message: "%{value} is not a channel; expected one of #{CANAIS.keys.join(", ")}" }
  validates :canal_detalhe, presence: { message: "is required when the channel is Outro" }, if: -> { canal == "outro" }
  validates :aprovado_em, presence: true
  validate :versao_da_arte
  validate :somente_artes

  def to_param
    uuid
  end

  def cancelada?
    cancelada_em.present?
  end

  # Usage: aprovacao.cancelar!(por: Current.user)
  def cancelar!(por:)
    update_columns(cancelada_em: Time.current, cancelada_por_id: por&.id)
  end

  # Usage: aprovacao.rotulo_canal # => "WhatsApp" / "Outro: Instagram"
  def rotulo_canal
    canal == "outro" ? "Outro: #{canal_detalhe}" : CANAIS.fetch(canal)
  end

  # Where the attachment lives: next to the arte's own files. Built only from
  # generated uuids and a fixed extension list — never from the stored file
  # name or anything user-typed (AGENTS.md "Security").
  def anexo_path
    extensao = AnexoDeAprovacao.extensao_do_tipo(anexo_tipo)
    return if anexo_arquivo.blank? || extensao.nil?

    File.join(ArquivoVersion::STORAGE_BASE, arquivo.uuid, "aprovacoes", "#{uuid}.#{extensao}")
  end

  private

  def versao_da_arte
    return if arquivo_version.nil? || arquivo_version.arquivo_id == arquivo_id

    errors.add(:arquivo_version, "v#{arquivo_version.version_number} belongs to another arquivo; expected a version of #{arquivo&.filename}")
  end

  # Cortes (DXF) are production files, not artwork a client approves.
  def somente_artes
    return if arquivo.nil? || !arquivo.corte?

    errors.add(:arquivo, "#{arquivo.filename} is a corte; only artes are approved")
  end
end
