module MovimentoCreatable
  extend ActiveSupport::Concern

  private

  def movimento_build
    normalize_decimal_separator
    load_form_data
    @movimento = MovimentoEstoque.new(movimento_params.except(:grupo_material_uuid, :cor_material_uuid, :largura, :gramatura))
  end

  def movimento_save
    mp = find_or_create_materia_prima
    unless mp
      flash.now[:alert] = "Invalid material: check group, color, width and weight."
      populate_selected_values
      render :new, status: :unprocessable_content
      return
    end

    @movimento.materia_prima = mp

    if @movimento.save
      redirect_to materiais_path, notice: "Movement registered: #{@movimento.tipo == 'entrada' ? 'In' : 'Out'} #{@movimento.quantidade} of #{mp.nome_completo} (#{@movimento.client.name})."
    else
      populate_selected_values
      render :new, status: :unprocessable_content
    end
  end

  def normalize_decimal_separator
    %w[largura quantidade valor].each do |field|
      raw = params.dig(:movimento_estoque, field)
      params[:movimento_estoque][field] = raw.sub(",", ".") if raw.is_a?(String)
    end
  end

  def populate_selected_values
    @selected_cor_uuid = movimento_params[:cor_material_uuid]
    @selected_grupo_uuid = movimento_params[:grupo_material_uuid]
    @largura_val = movimento_params[:largura]
    @gramatura_val = movimento_params[:gramatura]&.sub(/g\z/, "")
    @selected_client_nome = @movimento.client&.name
    @selected_grupo_nome = grupo_escolhido&.nome
  end

  def movimento_params
    params.require(:movimento_estoque).permit(:client_uuid, :tipo, :quantidade, :valor,
                                              :grupo_material_uuid, :cor_material_uuid, :largura, :gramatura)
  end

  def grupo_escolhido
    GrupoMaterial.find_by(uuid: movimento_params[:grupo_material_uuid].to_s)
  end

  def cor_escolhida
    CorMaterial.find_by(uuid: movimento_params[:cor_material_uuid].to_s)
  end

  # Unknown group/color uuids leave the reference nil, so the new material
  # fails validation and the form shows "Invalid material".
  def find_or_create_materia_prima
    atributos = { grupo_material: grupo_escolhido, cor_material: cor_escolhida,
                  largura: movimento_params[:largura], gramatura: movimento_params[:gramatura] }
    mp = MateriaPrima.find_by(atributos)
    return mp if mp

    mp = MateriaPrima.new(atributos)
    mp.save ? mp : nil
  end
end
