# The dublagem network, read only (Dublagem 2/5, decided 29/10/2026): each
# ligação of config/dublagens.yml with its ligantes, what each situação
# changes, before or after the estampa, what was guessed and what the
# registered groups contradict. The team's only: the ligante is the
# factory's, never the client's (plano Etapa 2.9).
class RedeDeDublagensController < ApplicationController
  exige :estoque, :ver, only: :show
  exige_equipe only: :show

  def show
    @grupos = visiveis(GrupoMaterial).to_a
    @situacoes = RedeDeDublagens.situacoes
    @ligacoes_por_grupo = RedeDeDublagens.ligacoes.group_by { |ligacao| ligacao.par.first }
    @avisos = RedeDeDublagens.ligacoes.index_with { |ligacao| RedeDeDublagens.avisos(ligacao, @grupos) }
  end
end
