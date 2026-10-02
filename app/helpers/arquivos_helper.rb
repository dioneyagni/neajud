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

    corte = arquivo.corte_via_molde
    tamanhos = corte&.tamanhos.presence || arquivo.tamanhos
    tamanhos.map { |t| { nome: t.nome } }
  end

  # The grade shown in the Mold Organization form: the corte's own, else the
  # one deduced from the detected names (Etapa 1.2, 1/3) — nil when nothing
  # can be deduced ("Size 1").
  # Usage: grade_proposta(corte) # => { tipo: "par", tamanhos: [{ nome: "23-24", numeros: %w[23 24] }, …] }
  def grade_proposta(corte)
    return { tipo: corte.tipo_grade, tamanhos: corte.tamanhos.map { |t| { nome: t.nome, numeros: t.numeros } } } if corte.tipo_grade

    GradeDoCorte.deduzir(corte.tamanhos.map(&:nome))
  end

  # What goes in a size's field: the pair "29-30", the furada's "24-25-26",
  # the P's numbers "33-34" (blank until known) — or the name without a type.
  # Usage: tamanhos_no_campo(tipo: "pmg", nome: "P", numeros: %w[33 34]) # => "33-34"
  def tamanhos_no_campo(tipo:, nome:, numeros:)
    return nome if tipo.nil? || %w[par impar].include?(tipo)

    numeros.join("-")
  end
end
