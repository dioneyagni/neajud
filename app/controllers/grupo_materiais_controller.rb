# The material groups as families (Dublagem 1/5, decided 27/10/2026): the
# list with each one's roles and printing, and the form that sets them and
# which attributes its materials ask for (GrupoMaterial). Created where they
# always were, in the stock entry's "+ Register new".
class GrupoMateriaisController < ApplicationController
  exige :estoque, :ver, only: :index
  exige :estoque, :editar, only: %i[edit update]

  def index
    @grupos = grupos_em_ordem
  end

  def edit
    @grupos = grupos_em_ordem
    @grupo = @grupos.por_uuid!(params[:id])
  end

  # Usage: PATCH /grupos-de-material/:uuid, grupo_material[superficie|base|estampavel|ressalva],
  #        pede[]=densidade, obrigatorios[]=espessura_mm
  def update
    @grupos = grupos_em_ordem
    @grupo = @grupos.por_uuid!(params[:id])
    @grupo.assign_attributes(params.require(:grupo_material).permit(:superficie, :base, :estampavel, :ressalva))
    @grupo.definir_atributos(pede: params[:pede], obrigatorios: params[:obrigatorios])
    return redirect_to edit_grupo_material_path(@grupo), notice: "#{@grupo.nome}: salvo." if @grupo.save

    flash.now[:alert] = "#{@grupo.nome}: #{@grupo.errors.full_messages.to_sentence}"
    render :edit, status: :unprocessable_content
  end

  private

  def grupos_em_ordem
    visiveis(GrupoMaterial).order(:nome)
  end
end
