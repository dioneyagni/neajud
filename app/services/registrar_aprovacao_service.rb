# Registers a client's approval of the arte's version in use (Etapa 0.5,
# 4/4), with the channel and an optional attachment. All or nothing: a bad
# attachment saves no approval.
#
# Usage: aprovacao = RegistrarAprovacaoService.call(arte, user: Current.user,
#          dados: { canal: "whatsapp", aprovado_em: "2026-09-28", observacao: "…" }, anexo: params[:anexo])
#        aprovacao.persisted? # => false with aprovacao.errors when invalid
class RegistrarAprovacaoService
  def self.call(arte, user:, dados:, anexo: nil)
    new(arte, user, dados.to_h.symbolize_keys, AnexoDeAprovacao.new(anexo)).call
  end

  def initialize(arte, user, dados, anexo)
    @anexo = anexo
    @aprovacao = AprovacaoArte.new(
      arquivo: arte, arquivo_version: arte.approved_version, user: user,
      canal: dados[:canal], canal_detalhe: dados[:canal_detalhe].presence, observacao: dados[:observacao].presence,
      aprovado_em: dados[:aprovado_em].presence || Date.current
    )
  end

  def call
    @aprovacao.validate
    @aprovacao.errors.add(:arquivo_version, "missing: the arte has no version yet") if @aprovacao.arquivo_version.nil?
    @aprovacao.errors.add(:anexo, @anexo.erro) if @anexo.erro
    return @aprovacao if @aprovacao.errors.any?

    AprovacaoArte.transaction do
      @aprovacao.save!
      @anexo.guardar!(@aprovacao) if @anexo.presente?
    end
    @aprovacao
  end
end
