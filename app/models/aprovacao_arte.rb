# A client's approval of one version of an arte, registered by the team
# ("Aprovação registrada por [nome], cliente aprovou por [canal]" —
# docs/plano.md), or given by the client himself in the system (canal
# "sistema", Etapa 2.8 4a — "Aprovada pelo cliente no sistema"), photographing
# the versions he chose. It never blocks production; the pedido only shows it.
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
  # Never in the team's form: only the client's own approval has it.
  CANAL_SISTEMA = "sistema".freeze

  belongs_to :user
  recusa_excluido :arquivo

  scope :recentes, -> { order(aprovado_em: :desc, id: :desc) }

  validates :canal, inclusion: { in: CANAIS.keys + [ CANAL_SISTEMA ], message: "%{value} is not a channel; expected one of #{(CANAIS.keys + [ CANAL_SISTEMA ]).join(", ")}" }
  validates :canal_detalhe, presence: { message: "is required when the channel is Outro" }, if: -> { canal == "outro" }
  validates :aprovado_em, presence: true

  # Usage: aprovacao.rotulo_canal # => "WhatsApp" / "Outro: Instagram" / "No sistema"
  def rotulo_canal
    return "No sistema" if no_sistema?

    canal == "outro" ? "Outro: #{canal_detalhe}" : CANAIS.fetch(canal)
  end

  def no_sistema?
    canal == CANAL_SISTEMA
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
