class MovimentosController < ApplicationController
  include MovimentoCreatable

  def index
    @movimentos = MovimentoEstoque.recentes.includes(:client, materia_prima: %i[grupo_material cor_material])
  end

  def new
    @cores = CorMaterial.order(:nome)
    @movimento = MovimentoEstoque.new
  end

  def create
    movimento_build
    movimento_save
  end

  private

  def load_form_data
    @cores = CorMaterial.order(:nome)
  end
end
