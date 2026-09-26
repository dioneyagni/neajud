module ExcluivelHelper
  # The "excluído em" badge next to a record in the trash that is still shown
  # where it was used (Etapa 0.4). Nil for active records.
  # Usage: <%= selo_excluido(item.arquivo) %>
  def selo_excluido(registro)
    return unless registro.respond_to?(:excluido?) && registro.excluido?

    tag.span("excluído em #{registro.deleted_at.strftime('%d/%m/%Y')}", class: "badge-excluido", title: "In the trash; restore it from Lixeira")
  end
end
