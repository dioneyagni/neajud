# The trash (Etapa 0.4): everything moved there instead of being deleted,
# newest first, with Restore. Until Etapa 0.5 (login) anyone can restore;
# then only the company owner.
class LixeiraController < ApplicationController
  exige :lixeira, :ver, only: :index
  # Lixeira's level 2 is "restaurar" (Autorizacao::NIVEL_MAXIMO).
  exige :lixeira, :editar, only: :restaurar
  # Route segment => model. Also the whitelist for #restaurar's :tipo.
  TIPOS = {
    "arquivos" => Arquivo, "pedidos" => Pedido, "clients" => Client,
    "modelos" => Modelo, "moldes" => Molde, "pecas" => Peca, "funcoes" => Funcao
  }.freeze

  def index
    @excluidos_por_tipo = TIPOS.transform_values { |model| model.excluidos.includes(exclusao_logs: :user).order(deleted_at: :desc) }
  end

  # Usage: POST /lixeira/clients/<uuid>/restaurar
  def restaurar
    registro = registro_excluido
    registro.restaurar!(**autoria)
    redirect_to lixeira_path, notice: "#{registro.model_name.human} \"#{registro.rotulo_lixeira}\" restored."
  end

  private

  def registro_excluido
    model = TIPOS.fetch(params[:tipo]) { raise ActionController::RoutingError, "Unknown trash type #{params[:tipo].inspect}; expected one of #{TIPOS.keys.join(", ")}" }
    model.excluidos.por_uuid!(params[:id])
  end
end
