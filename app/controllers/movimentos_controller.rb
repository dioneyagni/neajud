class MovimentosController < ApplicationController
  exige :estoque, :ver, only: :index
  exige :estoque, :editar, only: %i[new create]
  include MovimentoCreatable

  def index
    @movimentos = visiveis(MovimentoEstoque).recentes.includes(:client, :pedido, :baixa_producao, materia_prima: %i[grupo_material cor_material])
  end

  def new
    load_form_data
    @movimento = visiveis(MovimentoEstoque).new
  end

  def create
    movimento_build
    movimento_save
  end

  private

  def load_form_data
    @cores = visiveis(CorMaterial).order(:nome)
    @available_cor_names = CorMaterial::COLOR_HEX.keys - @cores.pluck(:nome)
  end
end
