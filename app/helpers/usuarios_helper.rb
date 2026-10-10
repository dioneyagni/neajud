module UsuariosHelper
  # The Usuários page rules for the signed-in manager.
  def gestao_de_usuarios
    @gestao_de_usuarios ||= GestaoDeUsuarios.new(Current.user)
  end

  # Funções the manager may give: the Dono função only if they are a dono.
  def funcoes_para_atribuir
    visiveis(Funcao).ativos.order(dono: :desc, nome: :asc).select { |funcao| dono? || !funcao.dono? }
  end

  # Usage: resumo_acessos_extras(vinculo) # => "Pedidos: Editar, Baixar arquivos de produção"
  def resumo_acessos_extras(vinculo)
    extras = vinculo&.acessos_extras.to_h
    itens = extras.fetch("niveis", {}).map { |area, nivel| "#{FuncoesHelper::ROTULOS_AREA.fetch(area)}: #{rotulo_de_nivel(area, nivel)}" }
    itens += Array(extras["acoes"]).map { |acao| FuncoesHelper::ROTULOS_ACAO.fetch(acao) }
    itens.presence&.join(", ") || "—"
  end
end
