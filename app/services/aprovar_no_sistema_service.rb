# The client approves an arte himself (Etapa 2.8, 4a, decided 12/10/2026):
# he picks one version of each active file — the one in use unless he chose
# another — and the approval photographs those. Versions in use → the arte is
# approved; others → "aprovada em outra versão" until the team uses them
# ("Usar esta versão"). Only while the arte waits for approval.
#
# Usage: aprovacao = AprovarNoSistemaService.call(arquivo, user: Current.user, versoes: { arquivo.uuid => versao.uuid })
#        aprovacao.persisted? # => false with aprovacao.errors when refused
class AprovarNoSistemaService
  def self.call(arquivo, user:, versoes: {})
    new(arquivo, user, versoes.to_h.stringify_keys).call
  end

  def initialize(arquivo, user, versoes)
    @arquivo = arquivo
    @user = user
    @versoes = versoes
  end

  def call
    escolhidas = versoes_escolhidas
    aprovacao = AprovacaoArte.new(arquivo: @arquivo, arquivo_version: escolhidas[@arquivo.id], user: @user, canal: AprovacaoArte::CANAL_SISTEMA,
                                  aprovado_em: Date.current, arquivo_version_ids: escolhidas.values.map(&:id))
    aprovacao.errors.add(:base, "#{@arquivo.filename} is #{@arquivo.rotulo_estado_aprovacao}; only an arte waiting for approval can be approved") unless @arquivo.estado_aprovacao == :aguardando
    aprovacao.save if aprovacao.errors.empty?
    aprovacao
  end

  private

  # { arquivo_id => ArquivoVersion }: another file's version raises RecordNotFound.
  def versoes_escolhidas
    @arquivo.arte.arquivos.ativos.where.not(approved_version_id: nil).order(:id).to_h do |arquivo|
      escolhida = @versoes[arquivo.uuid]
      [ arquivo.id, escolhida.present? ? arquivo.arquivo_versions.por_uuid!(escolhida) : arquivo.approved_version ]
    end
  end
end
