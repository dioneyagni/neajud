module ArquivosHelper
  # Whether the edit controls of an arquivo page show: Artes or, for a corte,
  # Catálogo at "editar" (the server checks the same in ArquivosController).
  # Usage: <% if pode_editar_arquivo?(@arquivo) %>…<% end %>
  def pode_editar_arquivo?(arquivo)
    pode?(arquivo.area_de_acesso, :editar)
  end

  def format_time(seconds)
    return "0:00" unless seconds

    hours = seconds / 3600
    mins = (seconds % 3600) / 60
    format("%d:%02d", hours, mins)
  end

  # Label for queued processing states (Etapa 0.3).
  # Usage: processamento_label("pending") # => "Na fila"
  def processamento_label(status)
    { "pending" => "Na fila", "processing" => "Processando" }.fetch(status, status.to_s.humanize)
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
