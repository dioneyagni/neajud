# The empty screens (Primeiros passos 1/6, decided 26/11/2026, canvas
# "Primeiros passos", 1–6): what config/mapa.yml says of a part, drawn in
# one of three sizes — the whole page, inside a section, a table row. The
# action shows to who may take it; "what comes before" (the map's falta,
# counted through Visibilidade) only to the team, its first missing part
# becoming the main action.
module EstadoVazioHelper
  TAMANHOS_DO_VAZIO = %i[pagina secao linha].freeze

  # Usage: estado_vazio(:pedido)                 # the whole page
  #        estado_vazio(:maquinas, tamanho: :secao)
  #        estado_vazio(:paradas, tamanho: :linha)
  def estado_vazio(id, tamanho: :pagina)
    raise ArgumentError, "#{tamanho.inspect} is not an empty-screen size; expected one of #{TAMANHOS_DO_VAZIO.join(", ")}" unless TAMANHOS_DO_VAZIO.include?(tamanho)

    parte = MapaDoSistema.parte(id)
    faltas = cliente_final? ? [] : MapaDoSistema.falta(id, visiveis: method(:visiveis))
    render "shared/estado_vazio", parte: parte, tamanho: tamanho, faltas: faltas, primeira: faltas.find { |falta| !falta.ok }
  end

  # A filter that left nothing (the second kind of empty): text only.
  # Usage: estado_sem_resultado("Nenhum pedido com esse filtro", limpar: pedidos_path)
  def estado_sem_resultado(texto, limpar:)
    tag.span(class: "estado-sem-resultado", data: { estado_sem_resultado: true }) { safe_join([ "#{texto} · ", link_to("Limpar filtros", limpar) ]) }
  end

  # A part's icon inline, so it takes the color of the text around it
  # (currentColor). Only the map's own names reach it.
  # Usage: icone_da_parte("cliente")
  def icone_da_parte(nome)
    EstadoVazioHelper.svg_da_parte(nome).html_safe # rubocop:disable Rails/OutputSafety -- our own files under app/assets, named by config/mapa.yml
  end

  def self.svg_da_parte(nome)
    @svgs ||= {}
    @svgs[nome] ||= Rails.root.join("app/assets/images/icons/partes/#{nome}.svg").read
  end

  # May the person take the map's action? "area:nivel", "acao:<ação>" or "dono".
  def pode_a_acao_do_mapa?(acao)
    return false unless acao

    tipo, valor = acao.permissao.to_s.split(":", 2)
    case tipo
    when "dono" then dono?
    when "acao" then pode_acao?(valor.to_sym)
    else pode?(tipo.to_sym, valor.to_sym)
    end
  end

  # Where a part's empty screen sends: its page, at the anchor of its action.
  def caminho_da_parte(parte)
    return unless parte.pagina

    ancora = parte.vazio&.acao&.tipo == "ancora" ? parte.vazio.acao.alvo : nil
    public_send("#{parte.pagina}_path", anchor: ancora)
  end

  # The part's own action as the page draws it.
  def acao_do_vazio(acao, classe:)
    case acao.tipo
    when "link" then link_to(acao.rotulo, public_send("#{acao.alvo}_path"), class: classe, data: { estado_vazio_acao: true })
    when "post" then button_to(acao.rotulo, public_send("#{acao.alvo}_path"), method: :post, class: classe, form: { class: "estado-vazio-form" }, data: { estado_vazio_acao: true })
    when "dialogo" then tag.button(acao.rotulo, type: "button", class: classe, data: { action: "click->dialog#open", estado_vazio_acao: true })
    else link_to(acao.rotulo, "##{acao.alvo}", class: classe, data: { estado_vazio_acao: true })
    end
  end
end
