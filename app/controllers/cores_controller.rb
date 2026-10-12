# "Cores" — every cor lisa (Etapa 2.5b, decided 12/10/2026, the layout in
# docs/cor-lisa/): the chart of tiles on top, the table below, filtered by
# family and material. Through Visibilidade: a cliente final sees his own and
# the coleção geral's.
class CoresController < ApplicationController
  exige :artes, :ver

  # Usage: GET /cores?familia=Laranja&materia_prima_uuid=…
  def index
    artes = visiveis(Arte).where(tipo: "cor_lisa").includes(:materia_prima)
    @familias = artes.where.not(familia: "").distinct.order(:familia).pluck(:familia)
    @materiais = visiveis(MateriaPrima).where(id: artes.select(:materia_prima_id)).order(:id)
    artes = artes.where(familia: params[:familia]) if params[:familia].present?
    artes = artes.where(materia_prima: visiveis(MateriaPrima).por_uuid!(params[:materia_prima_uuid])) if params[:materia_prima_uuid].present?
    @cores = artes.order(:familia, :numero).filter_map { |arte| (versao = arte.cor_medida) && [ arte, versao ] }
    @cartela = CartelaDeCores.call(@cores)
  end
end
