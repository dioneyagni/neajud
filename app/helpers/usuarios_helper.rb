module UsuariosHelper
  # The Usuários page rules for the signed-in manager.
  def gestao_de_usuarios
    @gestao_de_usuarios ||= GestaoDeUsuarios.new(Current.user)
  end

  # Funções the manager may give: the Dono função only if they are a dono;
  # a cliente final's (para_cliente: true) only funções para clientes, the
  # team's never one (Etapa 2.8, 2/5).
  # Usage: funcoes_para_atribuir(para_cliente: usuario.cliente.present?)
  def funcoes_para_atribuir(para_cliente: false)
    visiveis(Funcao).ativos.where(para_cliente: para_cliente).order(dono: :desc, nome: :asc).select { |funcao| dono? || !funcao.dono? }
  end

  # The grid rows a person's extra accesses may have: a cliente final's
  # without the team's (Autorizacao::AREAS_DA_EQUIPE / ACOES_DA_EQUIPE).
  # Usage: areas, acoes = grade_de_extras(para_cliente: true)
  def grade_de_extras(para_cliente:)
    return [ Autorizacao::AREAS, Autorizacao::ACOES ] unless para_cliente

    [ Autorizacao::AREAS - Autorizacao::AREAS_DA_EQUIPE, Autorizacao::ACOES - Autorizacao::ACOES_DA_EQUIPE ]
  end

  # Usage: resumo_acessos_extras(vinculo) # => "Pedidos: Editar, Baixar arquivos de produção"
  def resumo_acessos_extras(vinculo)
    extras = vinculo&.acessos_extras.to_h
    itens = extras.fetch("niveis", {}).map { |area, nivel| "#{FuncoesHelper::ROTULOS_AREA.fetch(area)}: #{rotulo_de_nivel(area, nivel)}" }
    itens += Array(extras["acoes"]).map { |acao| FuncoesHelper::ROTULOS_ACAO.fetch(acao) }
    itens.presence&.join(", ") || "—"
  end
end
