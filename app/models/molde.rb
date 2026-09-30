class Molde < ApplicationRecord
  include GeraUuid
  include Excluivel
  include ReferenciaAtiva

  belongs_to :client
  belongs_to :modelo, optional: true
  atribui_por_uuid :client, :modelo
  has_many :arquivos, dependent: :nullify
  has_many :arquivo_moldes, dependent: :destroy
  has_many :vinculated_arquivos, through: :arquivo_moldes, source: :arquivo
  has_many :molde_pecas, dependent: :destroy
  has_many :configured_pecas, through: :molde_pecas, source: :peca
  has_many :vinculo_logs_saida, class_name: "ArquivoVinculoLog", foreign_key: :from_molde_id, dependent: :nullify
  has_many :vinculo_logs_entrada, class_name: "ArquivoVinculoLog", foreign_key: :to_molde_id, dependent: :nullify

  recusa_excluido :client, :modelo
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

  def sync_molde_pecas!
    return unless modelo_id.present?

    modelo_peca_ids = ModeloPeca.where(modelo_id: modelo_id).pluck(:peca_id)

    existing = molde_pecas.index_by(&:peca_id)

    # A trashed peça keeps its existing row (and needs_cut) but gets no new one.
    Peca.ativos.where(id: modelo_peca_ids).pluck(:id).each do |peca_id|
      molde_pecas.find_or_create_by!(peca_id: peca_id) unless existing[peca_id]
    end

    molde_pecas.where.not(peca_id: modelo_peca_ids).delete_all
  end
end
