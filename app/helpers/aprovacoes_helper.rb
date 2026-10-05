module AprovacoesHelper
  # The client-approval badge of an arte (Etapa 0.5, 4/4; the arte's state
  # since Etapa 1.2, 2/3), or nil when it was never sent for approval — then nothing shows. In a
  # confirmed pedido, an arte still waiting shows it went ahead without the
  # approval; it never blocks (docs/plano.md).
  # Usage: <%= selo_aprovacao(arte, pedido: @pedido) %>
  # compacto: just the state (gallery card).
  def selo_aprovacao(arte, pedido: nil, compacto: false)
    return selo_compacto(arte) if compacto

    case arte.estado_aprovacao
    when :aprovada then selo_aprovada(arte.aprovacao_vigente)
    when :aguardando then selo_aguardando(arte.solicitacao_vigente, confirmado: pedido&.status == "confirmado")
    end
  end

  # What a request or an approval saw (Etapa 1.2, 2/3): "1 file (v2)" or
  # "3 files", the versions on hover.
  # Usage: <%= arquivos_da_foto(aprovacao) %>
  def arquivos_da_foto(registro)
    versoes = registro.versoes_por_arquivo
    texto = versoes.size == 1 ? "1 file (v#{ArquivoVersion.find(versoes.values.first).version_number})" : "#{versoes.size} files"
    tag.span(texto, title: descricao_da_foto(registro), class: "aprovacao-foto")
  end

  private

  ROTULOS_CURTOS = { aprovada: "✅ Aprovada", aguardando: "⏳ Aguardando" }.freeze

  def selo_compacto(arte)
    rotulo = ROTULOS_CURTOS[arte.estado_aprovacao]
    tag.span(rotulo, class: "badge-aprovacao badge-aprovacao--#{arte.estado_aprovacao}") if rotulo
  end

  def descricao_da_foto(registro)
    ArquivoVersion.where(id: registro.versoes_por_arquivo.values).includes(:arquivo).map { |v| "#{v.arquivo.filename} v#{v.version_number}" }.sort.join("; ")
  end

  def selo_aprovada(aprovacao)
    texto = "✅ Aprovada — #{aprovacao.rotulo_canal}, #{l(aprovacao.aprovado_em, format: '%d/%m/%Y')}"
    tag.span(texto, class: "badge-aprovacao badge-aprovacao--aprovada", title: "Registered by #{aprovacao.user.nome} · #{descricao_da_foto(aprovacao)}")
  end

  def selo_aguardando(solicitacao, confirmado:)
    return tag.span("⚠ Confirmado sem aprovação", class: "badge-aprovacao badge-aprovacao--sem") if confirmado

    enviada = "sent #{l(solicitacao.created_at.to_date, format: '%d/%m/%Y')} by #{solicitacao.user.nome}"
    tag.span("⏳ Aguardando aprovação", class: "badge-aprovacao badge-aprovacao--aguardando", title: enviada)
  end
end
