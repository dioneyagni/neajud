# An empty arte for a group of the upload (Etapa 1.2, 2/3 parte 3): the
# group's files are then sent one by one into it.
class ArtesController < ApplicationController
  before_action { exigir!(pode?(:artes, :editar), "artes: editar") }

  # Usage: POST /artes (tipo: dtf) → { "uuid": "…" }
  # Creates an empty arte of the group's kind (Etapa 2.5a); reads nothing.
  nao_le_registros only: :create

  def create
    arte = Arte.novo_do_tipo(params[:tipo])
    return render json: { error: arte.errors.full_messages.to_sentence }, status: :unprocessable_content unless arte.save

    render json: { uuid: arte.uuid }, status: :created
  end
end
