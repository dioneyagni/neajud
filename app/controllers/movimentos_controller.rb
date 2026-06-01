class MovimentosController < ApplicationController
  def index
    @movimentos = MovimentoEstoque.recentes.includes(:client, materia_prima: %i[grupo_material cor_material])
  end

  def new
    @movimento = MovimentoEstoque.new
  end

  def create
    normalize_decimal_separator

    mp = find_or_create_materia_prima
    unless mp
      redirect_to materiais_path, alert: "Invalid material: check group, color, width and weight."
      return
    end

    @movimento = mp.movimento_estoques.new(
      client_id: movimento_params[:client_id],
      tipo: movimento_params[:tipo],
      quantidade: movimento_params[:quantidade],
      valor: movimento_params[:valor].presence
    )

    if @movimento.save
      redirect_to materiais_path, notice: "Movement registered: #{@movimento.tipo == 'entrada' ? 'In' : 'Out'} #{@movimento.quantidade} of #{mp.nome_completo} (#{@movimento.client.name})."
    else
      redirect_to materiais_path, alert: @movimento.errors.full_messages.join(", ")
    end
  end

  private

  def normalize_decimal_separator
    %w[largura quantidade valor].each do |field|
      raw = params.dig(:movimento_estoque, field)
      params[:movimento_estoque][field] = raw.sub(",", ".") if raw.is_a?(String)
    end
  end

  def movimento_params
    params.require(:movimento_estoque).permit(:client_id, :tipo, :quantidade, :valor,
                                              :grupo_material_id, :cor_material_id, :largura, :gramatura)
  end

  def find_or_create_materia_prima
    mp = MateriaPrima.find_by(
      grupo_material_id: movimento_params[:grupo_material_id],
      cor_material_id: movimento_params[:cor_material_id],
      largura: movimento_params[:largura],
      gramatura: movimento_params[:gramatura]
    )
    return mp if mp

    mp = MateriaPrima.new(
      grupo_material_id: movimento_params[:grupo_material_id],
      cor_material_id: movimento_params[:cor_material_id],
      largura: movimento_params[:largura],
      gramatura: movimento_params[:gramatura]
    )
    mp.save ? mp : nil
  end
end
