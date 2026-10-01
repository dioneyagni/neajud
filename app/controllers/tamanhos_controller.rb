require "open3"

class TamanhosController < ApplicationController
  exige_acao :baixar_producao, only: :download
  exige :catalogo, :ver, only: :for_cascade
  before_action :set_tamanho, only: %i[download]

  # Production's download of one size (Etapa 0.6, 3/3): normally the DXF that
  # PreparacaoTamanhosJob already extracted; if asked before it is ready (or
  # the version changed), extracted now into the same place.
  def download
    arquivo = @tamanho.arquivo
    version = arquivo.approved_version
    raise ActionController::MissingFile unless version && File.exist?(version.original_path.to_s)

    caminho = @tamanho.dxf_extraido_path(version)
    extrair_dxf!(version, caminho) unless extraido_em_dia?(caminho, version)

    send_file caminho,
      type: "application/dxf",
      disposition: "attachment",
      # Corte name + size: on the factory floor a bare "30.dxf" is ambiguous.
      filename: "#{arquivo.filename} - #{@tamanho.nome}.dxf"
  rescue ActionController::MissingFile
    head :not_found
  end

  # The sizes of a molde's cortes of one piece (Arquivo.cortes_do_molde).
  # Usage: GET /tamanhos/for_cascade.json?molde_uuid=…&peca_uuid=… → [{ id:, nome:, width:, height: }]
  def for_cascade
    molde = Molde.find_by(uuid: params[:molde_uuid].to_s)
    arquivo_ids = Arquivo.cortes_do_molde(molde).where(peca: Peca.where(uuid: params[:peca_uuid])).pluck(:id)
    tamanhos = Tamanho.where(arquivo_id: arquivo_ids).order(:nome)
    render json: tamanhos.map { |t|
      { id: t.uuid, nome: t.nome, width: t.width_mm&.round(1), height: t.height_mm&.round(1) }
    }
  end

  private

  def extraido_em_dia?(caminho, version)
    File.exist?(caminho) && File.mtime(caminho) >= File.mtime(version.original_path)
  end

  def extrair_dxf!(version, caminho)
    FileUtils.mkdir_p(File.dirname(caminho))
    _stdout, stderr, status = Open3.capture3(
      "node", Rails.root.join("bin", "extract-tamanho-dxf.js").to_s,
      version.original_path.to_s, caminho, @tamanho.position.to_s
    )
    return if status.success?

    Rails.logger.error "extract-tamanho-dxf.js failed (position=#{@tamanho.position}): #{stderr.strip}"
    raise "Failed to extract tamanho #{@tamanho.uuid} (position #{@tamanho.position}) from #{version.original_path}"
  end

  def set_tamanho
    @tamanho = Tamanho.por_uuid!(params[:id])
  end
end
