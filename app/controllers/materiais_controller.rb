class MateriaisController < ApplicationController
  include MovimentoCreatable

  def index
    @movimentos = MovimentoEstoque.recentes.includes(:client, materia_prima: %i[grupo_material cor_material])
    @materiais = MateriaPrima.includes(:grupo_material, :cor_material).order(:largura)

    @saldo_cache = compute_saldos
    @total_saldo = @saldo_cache.values.sum
  end

  def new
    load_form_data
    @movimento = MovimentoEstoque.new(client_id: params[:client_id])
    @selected_client_nome = Client.find_by(id: params[:client_id])&.name
  end

  def create
    movimento_build
    movimento_save
  end

  def grupos
    grupos = params[:q].present? ? GrupoMaterial.search(params[:q]) : GrupoMaterial.order(:nome)
    render json: grupos.limit(10).map { |g| { id: g.id, nome: g.nome } }
  end

  def create_grupo
    create_reference_record(GrupoMaterial, "Group", params.require(:grupo_material).permit(:nome))
  end

  def cores
    render json: CorMaterial.order(:nome).map { |c| { id: c.id, nome: c.nome } }
  end

  def create_cor
    create_reference_record(CorMaterial, "Color", params.require(:cor_material).permit(:nome))
  end

  def search
    materiais = MateriaPrima.includes(:grupo_material, :cor_material)

    if params[:client_id].present?
      client_material_ids = MovimentoEstoque.where(client_id: params[:client_id])
        .distinct.pluck(:materia_prima_id)
      materiais = materiais.where(id: client_material_ids)
    end

    if params[:q].present?
      q = "%#{params[:q].to_s.gsub(/[%_]/, '\\\\\0')}%"
      materiais = materiais
        .joins(:grupo_material, :cor_material)
        .where("grupo_materiais.nome LIKE ? OR cor_materiais.nome LIKE ? OR materia_primas.largura LIKE ? OR materia_primas.gramatura LIKE ?", q, q, q, q)
    end
    render json: materiais.limit(20).map { |m|
      { id: m.id, nome_completo: m.nome_completo, saldo: m.saldo }
    }
  end

  private

  # Shared by create_grupo/create_cor: both are single-field ("nome")
  # reference tables with the same "already exists?" + save + flash shape.
  def create_reference_record(klass, label, permitted)
    existing = klass.where("LOWER(nome) = ?", permitted[:nome].to_s.downcase).first
    if existing
      redirect_to materiais_path, alert: "#{label} \"#{existing.nome}\" already exists."
      return
    end

    record = klass.new(permitted)
    if record.save
      redirect_to materiais_path, notice: "#{label} created."
    else
      redirect_to materiais_path, alert: record.errors.full_messages.join(", ")
    end
  end

  def load_form_data
    @grupos = GrupoMaterial.order(:nome)
    @cores = CorMaterial.order(:nome)
    @available_cor_names = CorMaterial::COLOR_HEX.keys - @cores.pluck(:nome)
  end

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
end
