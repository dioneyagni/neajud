module MovimentoCreatable
  extend ActiveSupport::Concern

  private

  def movimento_build
    normalize_decimal_separator
    load_form_data
    atributos = movimento_params.except(:grupo_material_uuid, :cor_material_uuid, :largura, *GrupoMaterial::ATRIBUTOS)
    # Etapa 2.3: the empresa's own stock has no client.
    atributos = atributos.except(:client_uuid) if ActiveModel::Type::Boolean.new.cast(atributos[:da_empresa])
    @movimento = visiveis(MovimentoEstoque).new(atributos)
  end

  def movimento_save
    mp = find_or_create_materia_prima
    unless mp.persisted?
      # Dublagem 1/5: which field the group requires, not a generic refusal.
      flash.now[:alert] = "Invalid material: #{mp.errors.full_messages.to_sentence.presence || "check group, color and width"}."
      populate_selected_values
      render :new, status: :unprocessable_content
      return
    end

    @movimento.materia_prima = mp

    if @movimento.save
      redirect_to materiais_path, notice: "Movement registered: #{@movimento.tipo == 'entrada' ? 'In' : 'Out'} #{@movimento.quantidade} m of #{mp.nome_completo} (#{@movimento.dono})."
    else
      # The form re-rendered without saying why (until Etapa 2.3).
      flash.now[:alert] = @movimento.errors.full_messages.to_sentence
      populate_selected_values
      render :new, status: :unprocessable_content
    end
  end

  def normalize_decimal_separator
    %w[largura quantidade valor espessura_mm].each do |field|
      raw = params.dig(:movimento_estoque, field)
      params[:movimento_estoque][field] = raw.sub(",", ".") if raw.is_a?(String)
    end
  end

  def populate_selected_values
    @selected_cor_uuid = movimento_params[:cor_material_uuid]
    @selected_grupo_uuid = movimento_params[:grupo_material_uuid]
    # The slider's number: "1.40 m" fit no range and the width came back
    # as 1,25 m after a refused entry (found by Dublagem 1/5's E2E).
    @largura_val = movimento_params[:largura]&.sub(/\s*m\z/, "")
    @gramatura_val = movimento_params[:gramatura]&.sub(/g\z/, "")
    @atributos_val = movimento_params.slice(*GrupoMaterial::ATRIBUTOS)
    @selected_client_nome = @movimento.client&.name
    @selected_grupo_nome = grupo_escolhido&.nome
    @selected_grupo_atributos = grupo_escolhido&.atributos
  end

  def movimento_params
    params.require(:movimento_estoque).permit(:client_uuid, :da_empresa, :tipo, :quantidade, :valor,
                                              :grupo_material_uuid, :cor_material_uuid, :largura, *GrupoMaterial::ATRIBUTOS)
  end

  def grupo_escolhido
    visiveis(GrupoMaterial).find_by(uuid: movimento_params[:grupo_material_uuid].to_s)
  end

  def cor_escolhida
    visiveis(CorMaterial).find_by(uuid: movimento_params[:cor_material_uuid].to_s)
  end

  # Unknown group/color uuids leave the reference nil, so the new material
  # fails validation and the form shows "Invalid material". Unsaved when
  # invalid, with its errors.
  def find_or_create_materia_prima
    atributos = atributos_do_material
    mp = visiveis(MateriaPrima).find_by(atributos)
    return mp if mp

    visiveis(MateriaPrima).new(atributos).tap(&:save)
  end

  # Only what the group asks for (Dublagem 1/5): a field it doesn't ask is
  # dropped, so the same material is found again whatever the form sent.
  def atributos_do_material
    grupo = grupo_escolhido
    atributos = { grupo_material: grupo, cor_material: cor_escolhida, largura: movimento_params[:largura] }
    GrupoMaterial::ATRIBUTOS.each do |atributo|
      atributos[atributo.to_sym] = (movimento_params[atributo].to_s.squish.presence if grupo&.pede?(atributo))
    end
    atributos.merge(gramatura: atributos[:gramatura].to_s)
  end
end
