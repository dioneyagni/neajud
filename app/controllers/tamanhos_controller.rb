require "open3"

class TamanhosController < ApplicationController
  before_action :set_tamanho

  def download
    stamp = @tamanho.stamp
    version = stamp.approved_version
    raise ActionController::MissingFile unless version && File.exist?(version.original_path.to_s)

    output_dir = Rails.root.join("tmp", "tamanho_extracts", stamp.uuid)
    FileUtils.mkdir_p(output_dir)
    output_path = output_dir.join("#{@tamanho.nome}.dxf")

    unless File.exist?(output_path.to_s) && File.mtime(output_path) >= File.mtime(version.original_path)
      stdout, stderr, status = Open3.capture3(
        "node", Rails.root.join("bin", "extract-tamanho-dxf.js").to_s,
        version.original_path.to_s, output_path.to_s, @tamanho.position.to_s
      )
      unless status.success?
        Rails.logger.error "extract-tamanho-dxf.js failed (position=#{@tamanho.position}): #{stderr.strip}"
        raise "Failed to extract tamanho DXF"
      end
    end

    send_file output_path.to_s,
      type: "application/dxf",
      disposition: "attachment",
      filename: "#{@tamanho.nome}.dxf"
  rescue ActionController::MissingFile
    head :not_found
  end

  private

  def set_tamanho
    @tamanho = Tamanho.find(params[:id])
  end
end
