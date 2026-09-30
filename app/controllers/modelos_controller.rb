# The official categories (Etapa 1.1, 3/5): read only. They come from
# config/catalogo_oficial.yml (CatalogoOficial); the company asks Neajud to
# add one instead of registering it.
class ModelosController < ApplicationController
  exige :catalogo, :ver
  before_action :set_modelo, only: :show

  def index
    @produtos = Produto.ativos.includes(:modelos).order(:nome)
    @arquivos_por_modelo = Arquivo.ativos.where.not(modelo_id: nil).group(:modelo_id).count
  end

  def show
    @arquivos = @modelo.arquivos.ativos.includes(approved_version: :image_metadata).order(created_at: :desc)
  end

  # Usage: GET /modelos/search.json?q=jog → [{ id: <uuid>, nome: "Jogging", abreviacao: "JGG" }]
  def search
    modelos = Modelo.ativos.search(params[:q]).order(:nome).limit(10)
    render json: modelos.map { |m| { id: m.uuid, nome: m.nome, abreviacao: m.abreviacao } }
  end

  private

  def set_modelo
    @modelo = Modelo.por_uuid!(params[:id])
  end
end
