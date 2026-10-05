# An empty arte for a group of the upload (Etapa 1.2, 2/3 parte 3): the
# group's files are then sent one by one into it.
class ArtesController < ApplicationController
  before_action { exigir!(pode?(:artes, :editar), "artes: editar") }

  # Usage: POST /artes → { "uuid": "…" }
  def create
    render json: { uuid: Arte.create!.uuid }, status: :created
  end
end
