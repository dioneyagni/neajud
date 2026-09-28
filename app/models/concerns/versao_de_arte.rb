# Shared by the approval records (SolicitacaoAprovacao, AprovacaoArte): they
# point at one version of one arte — the version must belong to that arquivo,
# and cortes (production files) are never sent for or given approval.
module VersaoDeArte
  extend ActiveSupport::Concern

  included do
    belongs_to :arquivo
    belongs_to :arquivo_version

    validate :versao_da_arte
    validate :somente_artes
  end

  private

  def versao_da_arte
    return if arquivo_version.nil? || arquivo_version.arquivo_id == arquivo_id

    errors.add(:arquivo_version, "v#{arquivo_version.version_number} belongs to another arquivo; expected a version of #{arquivo&.filename}")
  end

  def somente_artes
    return if arquivo.nil? || !arquivo.corte?

    errors.add(:arquivo, "#{arquivo.filename} is a corte; only artes go through approval")
  end
end
