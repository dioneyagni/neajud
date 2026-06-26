class MateriaisController < ApplicationController
  def index
    @movimentos = MovimentoEstoque.recentes.includes(:client, materia_prima: %i[grupo_material cor_material])
    @materiais = MateriaPrima.includes(:grupo_material, :cor_material).order(:largura)

    @saldo_cache = compute_saldos
    @total_saldo = @saldo_cache.values.sum
  end

  def new
    @grupos = GrupoMaterial.order(:nome)
    @cores = CorMaterial.order(:nome)
    @movimento = MovimentoEstoque.new
  end

  def create
    normalize_decimal_separator

    @grupos = GrupoMaterial.order(:nome)
    @cores = CorMaterial.order(:nome)
    @movimento = MovimentoEstoque.new(movimento_params.except(:grupo_material_id, :cor_material_id, :largura, :gramatura))

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

  def grupos
    grupos = params[:q].present? ? GrupoMaterial.search(params[:q]) : GrupoMaterial.order(:nome)
    render json: grupos.limit(10).map { |g| { id: g.id, nome: g.nome } }
  end

  def create_grupo
    existing = GrupoMaterial.where("LOWER(nome) = ?", params[:grupo_material][:nome].downcase).first
    if existing
      redirect_to materiais_path, alert: "Group \"#{existing.nome}\" already exists."
      return
    end

    grupo = GrupoMaterial.new(params.require(:grupo_material).permit(:nome))
    if grupo.save
      redirect_to materiais_path, notice: "Group created."
    else
      redirect_to materiais_path, alert: grupo.errors.full_messages.join(", ")
    end
  end

  def cores
    render json: CorMaterial.order(:nome).map { |c| { id: c.id, nome: c.nome } }
  end

  private

  def compute_saldos
    data = MovimentoEstoque.group(:materia_prima_id).select(
      "materia_prima_id",
      "SUM(CASE WHEN tipo = 'entrada' THEN quantidade ELSE 0 END) AS total_in",
      "SUM(CASE WHEN tipo = 'saida' THEN quantidade ELSE 0 END) AS total_out"
    )
    data.each_with_object({}) do |row, hash|
      hash[row.materia_prima_id] = row.total_in.to_f - row.total_out.to_f
    end
  end

  def normalize_decimal_separator
    %w[largura quantidade valor].each do |field|
      raw = params.dig(:movimento_estoque, field)
      params[:movimento_estoque][field] = raw.sub(",", ".") if raw.is_a?(String)
    end
  end

  def populate_selected_values
    @selected_cor_id = movimento_params[:cor_material_id]
    @selected_grupo_id = movimento_params[:grupo_material_id]
    @largura_val = movimento_params[:largura]
    @gramatura_val = movimento_params[:gramatura]&.sub(/g\z/, "")
    @selected_client_nome = Client.find_by(id: @movimento.client_id)&.name
    @selected_grupo_nome = GrupoMaterial.find_by(id: @selected_grupo_id)&.nome
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
