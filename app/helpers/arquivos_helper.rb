module ArquivosHelper
  def format_time(seconds)
    return "0:00" unless seconds

    hours = seconds / 3600
    mins = (seconds % 3600) / 60
    format("%d:%02d", hours, mins)
  end

  def preview_arquivo_url(arquivo)
    preview_arquivo_path(arquivo) if arquivo.preview_file.present?
  end

  def format_cm(pixels, dpi)
    return nil unless pixels && dpi&.positive?
    format("%.1f", pixels * 2.54 / dpi)
  end

  def tamanhos_for_arte(arquivo)
    return [] unless arquivo.category == "artes"

    corte = arquivo.corte_via_modelo
    tamanhos = corte&.tamanhos.presence || arquivo.tamanhos
    tamanhos.map { |t| { nome: t.nome } }
  end
end
