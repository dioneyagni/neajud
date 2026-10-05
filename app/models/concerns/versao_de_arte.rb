# Shared by the approval records (SolicitacaoAprovacao, AprovacaoArte): they
# belong to an arte (Etapa 1.2, 2/3) and photograph the version in use of each
# of its files (`arquivo_version_ids`). `arquivo` / `arquivo_version` are the
# file whose page it came from — the version must belong to that arquivo, and
# cortes (production files) are never sent for or given approval.
module VersaoDeArte
  extend ActiveSupport::Concern

  included do
    belongs_to :arquivo
    belongs_to :arquivo_version
    belongs_to :arte

    before_validation :fotografar_a_arte, on: :create

    validate :versao_da_arte
    validate :somente_artes
  end

  # Which version of each file it saw. Usage: registro.versoes_por_arquivo # => { 12 => 171 }
  def versoes_por_arquivo
    @versoes_por_arquivo ||= ArquivoVersion.where(id: arquivo_version_ids).pluck(:arquivo_id, :id).to_h
  end

  # Still about what the arte is: every file it saw that is still in the arte
  # keeps that version (files that left are ignored), and at least one is.
  # Usage: registro.valido_para?(arte.arquivos.ativos.pluck(:id, :approved_version_id).to_h)
  def valido_para?(em_uso)
    vistos = versoes_por_arquivo.slice(*em_uso.keys)
    vistos.any? && vistos.all? { |arquivo_id, versao_id| em_uso[arquivo_id] == versao_id }
  end

  private

  def fotografar_a_arte
    self.arte ||= arquivo&.arte
    self.arquivo_version_ids = arte.versoes_em_uso_ids if arte && arquivo_version_ids.blank?
  end

  def versao_da_arte
    return if arquivo_version.nil? || arquivo_version.arquivo_id == arquivo_id

    errors.add(:arquivo_version, "v#{arquivo_version.version_number} belongs to another arquivo; expected a version of #{arquivo&.filename}")
  end

  def somente_artes
    return if arquivo.nil? || !arquivo.corte?

    errors.add(:arquivo, "#{arquivo.filename} is a corte; only artes go through approval")
  end
end
