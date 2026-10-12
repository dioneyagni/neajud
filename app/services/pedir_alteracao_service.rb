# The client asks for changes to an arte, with a note (Etapa 2.8, 4a): the arte
# waits for the team ("alteração pedida") until it is sent for approval again.
# Only while the arte waits for approval.
#
# Usage: alteracao = PedirAlteracaoService.call(arquivo, user: Current.user, recado: "Azul mais escuro")
#        alteracao.persisted? # => false with alteracao.errors when refused
class PedirAlteracaoService
  def self.call(arquivo, user:, recado:)
    alteracao = AlteracaoArte.new(arquivo: arquivo, arquivo_version: arquivo.approved_version, user: user, recado: recado.to_s.strip.presence)
    alteracao.errors.add(:base, "#{arquivo.filename} is #{arquivo.rotulo_estado_aprovacao}; only an arte waiting for approval can get changes asked") unless arquivo.estado_aprovacao == :aguardando
    alteracao.save if alteracao.errors.empty?
    alteracao
  end
end
