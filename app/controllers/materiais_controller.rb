class MateriaisController < ApplicationController
  exige :estoque, :ver, only: %i[index grupos cores search]
  exige :estoque, :editar, only: %i[new create update create_grupo create_cor]
  include MovimentoCreatable

  def index
    @movimentos = visiveis(MovimentoEstoque).recentes.includes(:client, :pedido, :baixa_producao, materia_prima: %i[grupo_material cor_material])
    @materiais = visiveis(MateriaPrima).includes(:grupo_material, :cor_material).order(:largura)

    @saldos = SaldosDeEstoque.call(visiveis(MovimentoEstoque))
  end

  # A material's type and sale price per meter (Etapa 2.3).
  # Usage: PATCH /materiais/:uuid (materia_prima[tipo|preco_metro])
  def update
    material = visiveis(MateriaPrima).por_uuid!(params[:id])
    dados = params.require(:materia_prima).permit(:tipo, :preco_metro)
    dados[:preco_metro] = dados[:preco_metro].to_s.tr(",", ".").presence if dados.key?(:preco_metro)
    return redirect_to materiais_path, notice: "#{material.nome_completo} saved." if material.update(dados)

    redirect_to materiais_path, alert: "#{material.nome_completo}: #{material.errors.full_messages.to_sentence}"
  end

  def new
    load_form_data
    @movimento = visiveis(MovimentoEstoque).new(client: visiveis(Client).find_by(uuid: params[:client_uuid].to_s))
    @selected_client_nome = @movimento.client&.name
  end

  def create
    movimento_build
    movimento_save
  end

  def grupos
    grupos = params[:q].present? ? visiveis(GrupoMaterial).search(params[:q]) : visiveis(GrupoMaterial).order(:nome)
    # Dublagem 1/5: the stock entry shows the fields the group asks for.
    render json: grupos.limit(10).map { |g| { id: g.uuid, nome: g.nome, atributos: g.atributos } }
  end

  def create_grupo
    create_reference_record(visiveis(GrupoMaterial), "Group", params.require(:grupo_material).permit(:nome))
  end

  def cores
    render json: visiveis(CorMaterial).order(:nome).map { |c| { id: c.uuid, nome: c.nome } }
  end

  def create_cor
    create_reference_record(visiveis(CorMaterial), "Color", params.require(:cor_material).permit(:nome))
  end

  def search
    materiais = visiveis(MateriaPrima).includes(:grupo_material, :cor_material)

    if params[:client_uuid].present?
      client_material_ids = visiveis(MovimentoEstoque).where(client: visiveis(Client).where(uuid: params[:client_uuid]))
        .distinct.pluck(:materia_prima_id)
      materiais = materiais.where(id: client_material_ids)
    end
    # Etapa 2.7a: a tecido item is printed on a fabric.
    materiais = materiais.where(tipo: params[:tipo]) if MateriaPrima::TIPOS.include?(params[:tipo])
    # Dublagem 1/5: a corrida or cor lisa's item, only what prints.
    materiais = materiais.estampaveis if params[:estampavel].present?

    if params[:q].present?
      q = "%#{params[:q].to_s.gsub(/[%_]/, '\\\\\0')}%"
      materiais = materiais
        .joins(:grupo_material, :cor_material)
        .where("grupo_materiais.nome LIKE ? OR cor_materiais.nome LIKE ? OR materia_primas.largura LIKE ? OR materia_primas.gramatura LIKE ?", q, q, q, q)
    end
    render json: materiais.limit(20).map { |m|
      { id: m.uuid, nome_completo: m.nome_completo, saldo: m.saldo }
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
    @grupos = visiveis(GrupoMaterial).order(:nome)
    @cores = visiveis(CorMaterial).order(:nome)
    @available_cor_names = CorMaterial::COLOR_HEX.keys - @cores.pluck(:nome)
  end
end
