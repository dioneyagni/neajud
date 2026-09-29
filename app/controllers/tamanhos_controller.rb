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

  def for_cascade
    scope = Arquivo.ativos.where(organized: true, molde_id: params[:molde_id], peca_id: params[:peca_id])
    scope = scope.where(client_id: params[:client_id]) if params[:client_id].present?
    arquivo_ids = scope.pluck(:id)
    tamanhos = Tamanho.where(arquivo_id: arquivo_ids).order(:nome)
    render json: tamanhos.map { |t|
      { id: t.id, nome: t.nome, width: t.width_mm&.round(1), height: t.height_mm&.round(1) }
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
    raise "Failed to extract tamanho #{@tamanho.id} (position #{@tamanho.position}) from #{version.original_path}"
  end

  def set_tamanho
    @tamanho = Tamanho.find(params[:id])
  end
end
