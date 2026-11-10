# The rede's Situações card (rede editável 2/2b, decided 10/11/2026, canvas
# "2/2b · Rede: bloco Situações"): "+ Situação" and renaming, with the
# ligação's requirements — the rede's to see, the "Editar a rede de
# dublagens" action to change (Q7a of 2/2a). No trash on purpose.
class SituacoesDublagemController < ApplicationController
  exige :estoque, :ver
  exige_equipe
  exige_acao :editar_rede_de_dublagens

  # Usage: POST /rede-de-dublagens/situacoes, situacao[nome]
  def create
    salvar(visiveis(SituacaoDublagem).new, "criada")
  end

  # Usage: PATCH /rede-de-dublagens/situacoes/<uuid>, situacao[nome]
  def update
    salvar(visiveis(SituacaoDublagem).por_uuid!(params[:id]), "salva")
  end

  private

  def salvar(situacao, feito)
    nome = params.require(:situacao).permit(:nome)[:nome].to_s
    salva = SalvarSituacao.new(situacao, nome, construcoes: visiveis(Construcao), user: Current.user).call
    aviso = salva ? { notice: "Situação #{situacao.nome}: #{feito}." } : { alert: "Situação #{nome.squish.inspect}: #{situacao.errors.full_messages.to_sentence}" }
    redirect_to rede_de_dublagens_path(anchor: "situacoes"), **aviso
  end
end
