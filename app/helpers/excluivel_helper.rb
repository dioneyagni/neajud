module ExcluivelHelper
  # Icon per trashed type that has no preview of its own.
  ICONES_LIXEIRA = {
    "Client" => "icons/lixeira/client", "Modelo" => "icons/lixeira/modelo", "Molde" => "icons/lixeira/molde",
    "Peca" => "icons/lixeira/peca", "Pedido" => "icons/lixeira/pedido"
  }.freeze

  # The "excluído em" badge next to a record in the trash that is still shown
  # where it was used (Etapa 0.4). Nil for active records.
  # Usage: <%= selo_excluido(item.arquivo) %>
  def selo_excluido(registro)
    return unless registro.respond_to?(:excluido?) && registro.excluido?

    tag.span("excluído em #{registro.deleted_at.strftime('%d/%m/%Y')}", class: "badge-excluido", title: "In the trash; restore it from Lixeira")
  end

  # Thumbnail of a /lixeira row: the arte's preview (a pedido shows its first
  # arte), else an icon — the extension's for an arquivo, the type's otherwise.
  # Usage: <%= miniatura_lixeira(registro) %>
  def miniatura_lixeira(registro)
    arte = arte_com_preview(registro)
    return image_tag(preview_arquivo_path(arte), class: "lixeira-thumb", alt: arte.filename) if arte

    image_tag("#{icone_lixeira(registro)}.svg", class: "lixeira-thumb lixeira-thumb--icone", alt: registro.model_name.human)
  end

  private

  def arte_com_preview(registro)
    arte = registro.is_a?(Pedido) ? registro.itens_pedido.first&.arquivo : registro
    return unless arte.is_a?(Arquivo)

    arte if arte.preview_file.present? && File.exist?(arte.preview_file.to_s)
  end

  def icone_lixeira(registro)
    return FileCategory.extension_icon(registro.extension) if registro.is_a?(Arquivo)

    ICONES_LIXEIRA.fetch(registro.class.name)
  end
end
