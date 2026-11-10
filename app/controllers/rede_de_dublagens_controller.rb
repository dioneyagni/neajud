# The dublagem network, read only (Dublagem 2/5, decided 29/10/2026; from
# the database since rede editável 1/2): each ligação with its ligantes,
# what each situação changes, before or after the estampa, what was guessed
# and what the groups' roles contradict. The team's only: the ligante is the
# factory's, never the client's (plano Etapa 2.9).
class RedeDeDublagensController < ApplicationController
  exige :estoque, :ver, only: :show
  exige_equipe only: :show

  def show
    rede = RedeDeDublagens.new(ligacoes: visiveis(LigacaoDublagem), situacoes: visiveis(SituacaoDublagem))
    @situacoes = rede.situacoes
    @ligacoes_por_grupo = rede.ligacoes.group_by { |ligacao| ligacao.par.first }
    @avisos = rede.ligacoes.index_with { |ligacao| RedeDeDublagens.avisos(ligacao) }
    preparar_situacoes(rede)
  end

  private

  # The Situações card (rede editável 2/2b): each with how many ligações it
  # changes and how many construções have it, and the histórico (Q2a).
  def preparar_situacoes(rede)
    @registros_de_situacao = visiveis(SituacaoDublagem).order(:id)
    @ligacoes_por_situacao = rede.quantas_mudam
    @construcoes_por_situacao = visiveis(Construcao).ativos.where.not(situacao: nil).group(:situacao).count
    @alteracoes_de_situacao = visiveis(AlteracaoDaRede).where(registro_type: "SituacaoDublagem").recentes.includes(:user)
  end
end
