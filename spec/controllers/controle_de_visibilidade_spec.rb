require "rails_helper"

# Etapa 2.8 (1/5): an action that reads records without the visibility policy
# fails the specs, naming itself — a new screen can't forget it.
RSpec.describe ControleDeVisibilidade, type: :controller do
  controller(ApplicationController) do
    allow_unauthenticated_access
    nao_le_registros only: :declarada

    def index
      render plain: Pedido.count
    end

    def show
      render plain: visiveis(Pedido).count
    end

    def declarada
      render plain: "ok"
    end

    def recusada
      head :unprocessable_content
    end
  end

  before do
    routes.draw do
      get "anonymous" => "anonymous#index"
      get "anonymous/show" => "anonymous#show"
      get "anonymous/declarada" => "anonymous#declarada"
      get "anonymous/recusada" => "anonymous#recusada"
    end
  end

  it "raises when an action finished without visiveis, naming it" do
    expect { get :index }.to raise_error(ControleDeVisibilidade::VisibilidadeNaoAplicada, /#index finished without visiveis/)
  end

  it "lets through an action that used visiveis, one declared to read nothing, and a refusal" do
    expect { get :show }.not_to raise_error
    expect { get :declarada }.not_to raise_error
    expect { get :recusada }.not_to raise_error
  end
end
