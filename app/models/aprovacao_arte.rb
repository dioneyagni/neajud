# A client's approval of one version of an arte, registered by the team
# ("Aprovação registrada por [nome], cliente aprovou por [canal]" —
# docs/plano.md). It never blocks production; the pedido only shows it.
# A new version starts "aguardando" again: approvals are per version.
# Cancelled by mistake → cancelada_em (kept in the history, never deleted).
class AprovacaoArte < ApplicationRecord
  self.table_name = "aprovacoes_arte"

  include GeraUuid
  include ReferenciaAtiva
  include VersaoDeArte
  include Cancelavel

  CANAIS = {
    "whatsapp" => "WhatsApp", "email" => "E-mail", "telefone" => "Telefone",
    "presencial" => "Presencial", "outro" => "Outro"
  }.freeze

  belongs_to :user
  recusa_excluido :arquivo

  scope :recentes, -> { order(aprovado_em: :desc, id: :desc) }

  validates :canal, inclusion: { in: CANAIS.keys, message: "%{value} is not a channel; expected one of #{CANAIS.keys.join(", ")}" }
  validates :canal_detalhe, presence: { message: "is required when the channel is Outro" }, if: -> { canal == "outro" }
  validates :aprovado_em, presence: true

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
end
