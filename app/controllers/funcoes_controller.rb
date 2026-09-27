# The permission grid (Etapa 0.5, 2/4): the dono edits what each função may
# do, creates funções (many workers share one) and deletes unused ones.
# Only the dono: editing it is how permissions are granted.
class FuncoesController < ApplicationController
  exige_dono

  def index
    @funcoes = Funcao.ativos.order(dono: :desc, id: :asc)
    @usuarios_por_funcao = Vinculo.group(:funcao_id).count
  end

  def create
    funcao = Funcao.new(nome: params.dig(:funcao, :nome).to_s.strip)
    return redirect_to funcoes_path, notice: "Função \"#{funcao.nome}\" created: choose what it may do." if funcao.save

    redirect_to funcoes_path, alert: funcao.errors.full_messages.to_sentence
  end

  # Usage: PATCH /funcoes/atualizar with funcoes[<uuid>][nome|niveis|acoes]
  def atualizar
    erros = FuncoesGradeService.call(grade_params)
    return redirect_to funcoes_path, notice: "Funções saved." if erros.empty?

    redirect_to funcoes_path, alert: erros.to_sentence
  end

  def destroy
    funcao = Funcao.ativos.find_by!(uuid: params[:uuid])
    funcao.excluir!(**autoria)
    redirect_to funcoes_path, notice: "Função \"#{funcao.nome}\" moved to the trash."
  rescue Funcao::EmUso => e
    redirect_to funcoes_path, alert: e.message
  end

  private

  # Keyed by função uuid; only name, the known áreas and actions pass.
  def grade_params
    params.fetch(:funcoes, ActionController::Parameters.new).each_pair.to_h do |uuid, linha|
      [ uuid, linha.permit(:nome, niveis: Autorizacao::AREAS, acoes: []).to_h ]
    end
  end
end
