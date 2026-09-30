class Modelo < ApplicationRecord
  include GeraUuid
  include Excluivel
  include ReferenciaAtiva

  belongs_to :client
  belongs_to :molde, optional: true
  atribui_por_uuid :client, :molde
  has_many :arquivos, dependent: :nullify
  has_many :arquivo_modelos, dependent: :destroy
  has_many :vinculated_arquivos, through: :arquivo_modelos, source: :arquivo
  has_many :modelo_pecas, dependent: :destroy
  has_many :configured_pecas, through: :modelo_pecas, source: :peca
  has_many :vinculo_logs_saida, class_name: "ArquivoVinculoLog", foreign_key: :from_modelo_id, dependent: :nullify
  has_many :vinculo_logs_entrada, class_name: "ArquivoVinculoLog", foreign_key: :to_modelo_id, dependent: :nullify

  recusa_excluido :client, :molde
  validates :nome, presence: true
  validates :nome, uniqueness: { scope: :client_id, case_sensitive: false }

  scope :search, ->(q) {
    return all if q.blank?
    pattern = "%#{q.to_s.gsub(/[%_]/, '\\\\\0')}%"
    where("nome LIKE ?", pattern)
  }

  scope :for_client, ->(client_id) {
    where(client_id: client_id)
  }

  def sync_modelo_pecas!
    return unless molde_id.present?

    molde_peca_ids = MoldePeca.where(molde_id: molde_id).pluck(:peca_id)

    existing = modelo_pecas.index_by(&:peca_id)

    # A trashed peça keeps its existing row (and needs_cut) but gets no new one.
    Peca.ativos.where(id: molde_peca_ids).pluck(:id).each do |peca_id|
      modelo_pecas.find_or_create_by!(peca_id: peca_id) unless existing[peca_id]
    end

    modelo_pecas.where.not(peca_id: molde_peca_ids).delete_all
  end
end
