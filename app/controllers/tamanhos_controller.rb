class TamanhosController < ApplicationController
  exige_acao :baixar_producao, only: :download
  exige :catalogo, :ver, only: :for_cascade
  exige :pedidos, :ver, only: :preview
  before_action :set_tamanho, only: %i[download preview]

  # Production's download of one size (DxfDoTamanho: extracted by
  # PreparacaoTamanhosJob, or now if not ready).
  def download
    send_file DxfDoTamanho.caminho!(@tamanho),
      type: "application/dxf",
      disposition: "attachment",
      # Corte name + size: on the factory floor a bare "30.dxf" is ambiguous.
      filename: "#{@tamanho.arquivo.filename} - #{@tamanho.nome}.dxf"
  rescue ActionController::MissingFile
    head :not_found
  end

  # The size's drawing (PNG made with its DXF) for the Corte page (Etapa
  # 1.2, 3/3 parte 3b). The path is rebuilt from the version and position,
  # never read from the column.
  def preview
    caminho = @tamanho.preview_png_path(@tamanho.arquivo.approved_version)
    return head(:not_found) unless caminho && File.exist?(caminho)

    send_file caminho, type: "image/png", disposition: "inline"
  end

  # The sizes of a molde's cortes of one piece (Arquivo.cortes_do_molde).
  # Usage: GET /tamanhos/for_cascade.json?molde_uuid=…&peca_uuid=… → [{ id:, nome:, width:, height: }]
  def for_cascade
    molde = visiveis(Molde).find_by(uuid: params[:molde_uuid].to_s)
    arquivo_ids = visiveis(Arquivo).cortes_do_molde(molde).where(peca: visiveis(Peca).where(uuid: params[:peca_uuid])).pluck(:id)
    tamanhos = visiveis(Tamanho).where(arquivo_id: arquivo_ids).order(:nome)
    render json: tamanhos.map { |t|
      { id: t.uuid, nome: t.nome, width: t.width_mm&.round(1), height: t.height_mm&.round(1) }
    }
  end

  private

  def set_tamanho
    @tamanho = visiveis(Tamanho).por_uuid!(params[:id])
  end
end
