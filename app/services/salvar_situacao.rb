# Adds or renames a situação from the rede's page (rede editável 2/2b,
# decided 10/11/2026), with a line in its histórico (Q2a). A rename also
# renames the construções not in use that have it — their name, the
# dublado's, carries the situação (Q1b) —; the ones in use keep the name
# the stock and the pedidos already show. Only the name is written: a
# construção that breaks today's network rules still gets it.
#
# construcoes: the visible scope to rename in.
#
# Usage: SalvarSituacao.new(SituacaoDublagem.new, "Tecido úmido", construcoes: visiveis(Construcao), user: Current.user).call # => true
#        SalvarSituacao.new(tecido_molha, "Tecido úmido", construcoes: visiveis(Construcao), user: Current.user).call # => true ("renomeou … ; 2 construções renomeadas")
class SalvarSituacao
  def initialize(situacao, nome, construcoes:, user:)
    @situacao = situacao
    @nome = nome
    @construcoes = construcoes
    @user = user
  end

  # false with the reasons in situacao.errors; nothing written.
  def call
    nova = @situacao.new_record?
    antes = @situacao.nome
    @situacao.nome = @nome
    return true if !nova && !@situacao.nome_changed?

    SituacaoDublagem.transaction do
      @situacao.save!
      @situacao.alteracoes.create!(texto: nova ? "criou #{@situacao.nome}" : texto_da_troca(antes), user: @user)
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  private

  def texto_da_troca(antes)
    renomeadas = renomear_construcoes
    [ "renomeou #{antes} → #{@situacao.nome}", renomeadas.positive? && "#{renomeadas} #{renomeadas == 1 ? "construção renomeada" : "construções renomeadas"}" ].compact_blank.join("; ")
  end

  # The network read so far still has the old name.
  def renomear_construcoes
    RedeDeDublagens.esquecer
    @construcoes.where(situacao: @situacao.chave).includes(camadas: :materia_prima).reject(&:em_uso?)
                .count { |construcao| construcao.update_column(:nome, construcao.nome_montado) }
  end
end
