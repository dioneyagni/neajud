module AprovacoesHelper
  # The client-approval badge of an arte (Etapa 0.5, 4/4), or nil when the
  # version in use was never sent for approval — then nothing shows. In a
  # confirmed pedido, an arte still waiting shows it went ahead without the
  # approval; it never blocks (docs/plano.md).
  # Usage: <%= selo_aprovacao(arte, pedido: @pedido) %>
  def selo_aprovacao(arte, pedido: nil)
    case arte.estado_aprovacao
    when :aprovada then selo_aprovada(arte.aprovacao_vigente)
    when :aguardando then selo_aguardando(arte.solicitacao_vigente, confirmado: pedido&.status == "confirmado")
    end
  end

  private

  def selo_aprovada(aprovacao)
    texto = "✅ Aprovada — v#{aprovacao.arquivo_version.version_number}, #{aprovacao.rotulo_canal}, #{l(aprovacao.aprovado_em, format: '%d/%m/%Y')}"
    tag.span(texto, class: "badge-aprovacao badge-aprovacao--aprovada", title: "Registered by #{aprovacao.user.nome}")
  end

  def selo_aguardando(solicitacao, confirmado:)
    return tag.span("⚠ Confirmado sem aprovação", class: "badge-aprovacao badge-aprovacao--sem") if confirmado

    enviada = "sent #{l(solicitacao.created_at.to_date, format: '%d/%m/%Y')} by #{solicitacao.user.nome}"
    tag.span("⏳ Aguardando aprovação", class: "badge-aprovacao badge-aprovacao--aguardando", title: enviada)
  end
end
