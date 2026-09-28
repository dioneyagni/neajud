module AprovacoesHelper
  # The client-approval badge of an arte (Etapa 0.5, 4/4). In a confirmed
  # pedido an arte still waiting shows it went ahead without approval — it
  # never blocks (docs/plano.md).
  # Usage: <%= selo_aprovacao(arte, pedido: @pedido) %>
  def selo_aprovacao(arte, pedido: nil)
    aprovacao = arte.aprovacao_vigente
    return selo_aprovada(aprovacao) if aprovacao
    return tag.span("⚠ Confirmado sem aprovação", class: "badge-aprovacao badge-aprovacao--sem") if pedido&.status == "confirmado"

    anterior = arte.aprovada_versao_anterior? ? " (an earlier version was approved)" : ""
    tag.span("⏳ Aguardando aprovação#{anterior}", class: "badge-aprovacao badge-aprovacao--aguardando")
  end

  private

  def selo_aprovada(aprovacao)
    texto = "✅ Aprovada — v#{aprovacao.arquivo_version.version_number}, #{aprovacao.rotulo_canal}, #{l(aprovacao.aprovado_em, format: '%d/%m/%Y')}"
    tag.span(texto, class: "badge-aprovacao badge-aprovacao--aprovada", title: "Registered by #{aprovacao.user.nome}")
  end
end
