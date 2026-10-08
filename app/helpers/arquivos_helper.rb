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

  # The size on disk of a file's version in use: the piloto is the heavy one.
  # Usage: peso_do_arquivo(piloto) # => "78.1 MB"
  def peso_do_arquivo(arquivo)
    caminho = arquivo.approved_original_path
    number_to_human_size(File.size(caminho)) if caminho && File.exist?(caminho)
  end

  # A small preview of a file (the arte's file list and join cards, Etapa
  # 1.2 2/3), lazy so a long list doesn't load every image; the format icon
  # while there is none (queued, failed, not an image).
  # Usage: miniatura_do_arquivo(arquivo, classe: "arte-arquivo-thumb")
  def miniatura_do_arquivo(arquivo, classe:)
    if arquivo.preview_file.present? && File.exist?(arquivo.preview_file)
      image_tag preview_arquivo_path(arquivo, t: arquivo.approved_version&.updated_at&.to_i), class: classe, alt: arquivo.filename, loading: "lazy"
    else
      image_tag "#{FileCategory.extension_icon(arquivo.extension)}.svg", class: "#{classe} #{classe}--icone", alt: arquivo.extension
    end
  end

  def format_cm(pixels, dpi)
    return nil unless pixels && dpi&.positive?
    format("%.1f", pixels * 2.54 / dpi)
  end

  # The sizes the pedido grade offers for an arte (Etapa 1.2, 3/3: one by one,
  # Arte#tamanhos_do_pedido). Usage: tamanhos_for_arte(arquivo) # => [{ nome: "24" }, …]
  def tamanhos_for_arte(arquivo)
    return [] unless arquivo.category == "artes" && arquivo.arte

    arquivo.arte.tamanhos_do_pedido.map { |nome| { nome: nome } }
  end

  # Usage: grade_completa_for_arte(arquivo) # => ["18", …, "46"]
  def grade_completa_for_arte(arquivo)
    return [] unless arquivo.category == "artes" && arquivo.arte

    arquivo.arte.grade_completa_do_pedido
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

  # What a gallery card says about its arte (Etapa 1.2, 2/3 parte 3): its
  # files' names and whether any is still queued — one card stands for the
  # whole arte, so E2E waits for an uploaded file through its arte's card.
  # Usage: tag.div(data: { **dados_da_arte_no_card(arquivo) })
  def dados_da_arte_no_card(arquivo)
    return {} unless arquivo.arte

    membros = arquivo.arte.arquivos.ativos.includes(:approved_version).to_a
    { arte_arquivos: membros.map(&:filename).join("|"), arte_em_fila: membros.any? { |m| m.pending? || m.processing? } }
  end

  # The other files of an arte on its gallery card (Etapa 1.2, 2/3), nil for
  # an arte of one file: "3 files · Lateral 29-30, 31-32 · Língua 29-30".
  # Usage: resumo_da_arte(arquivo) # => "2 files · Lateral 29-30, 31-32"
  def resumo_da_arte(arquivo)
    return nil unless arquivo.arte

    partes = arquivo.arte.arquivos_por_parte
    total = partes.values.sum(&:size)
    return nil if total < 2

    tamanhos = partes.map { |peca, lista| [ peca&.nome || "No part", lista.map { |a| a.rotulo_de_tamanho || "?" }.join(", ") ].join(" ") }
    "#{total} files · #{tamanhos.join(" · ")}"
  end

  # How much paper one printed piece of this file takes on the paper's width
  # (Etapa 2.2, 1/3): pieces per meter and the share of a meter; nil without
  # the file's size/DPI or when it doesn't fit the roll.
  # Usage: consumo_de_papel(arquivo, 1600) # => "40,8 por metro · 2,45% do metro"
  def consumo_de_papel(arquivo, largura_mm)
    metros = largura_mm && arquivo.approved_version&.metros_por_peca(largura_mm)
    return nil unless metros

    por_metro = number_with_precision(1 / metros, precision: 1, separator: ",")
    "#{por_metro} por metro · #{number_with_precision(metros * 100, precision: 2, separator: ",")}% do metro"
  end

  # Pieces per meter of fabric of a DXF size on each width it was fitted on
  # (Etapa 2.2, 1/3); nil while none was computed.
  # Usage: pecas_por_metro_do_tamanho(tamanho) # => "1,25 m: 50,7 peças/m · 1,60 m: 64,5 peças/m"
  def pecas_por_metro_do_tamanho(tamanho)
    larguras = tamanho.metros_por_peca.select { |_, metros| metros.to_f.positive? }.sort_by { |largura, _| largura.to_i }
    return nil if larguras.empty?

    larguras.map do |largura, metros|
      "#{number_with_precision(largura.to_i / 1000.0, precision: 2, separator: ",")} m: #{number_with_precision(1 / metros.to_f, precision: 1, separator: ",")} peças/m"
    end.join(" · ")
  end
end
