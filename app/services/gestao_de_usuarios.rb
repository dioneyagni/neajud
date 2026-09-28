# The rules of who may manage whom (Etapa 0.5, 3/4), for the Usuários page:
# - only the dono manages donos and gives the Dono função;
# - a non-dono manager can't give more than they have themselves (per área
#   and per special action), so "gerenciar usuários" is never a way up;
# - the empresa always keeps an active dono, and nobody deactivates themselves.
#
# Usage: gestao = GestaoDeUsuarios.new(Current.user)
#        gestao.pode_gerir?(joao)
#        gestao.erros_de_atribuicao(joao, funcao, { "niveis" => { "pedidos" => 2 } }) # => []
class GestaoDeUsuarios
  def initialize(gestor)
    @gestor = gestor
    @minha = gestor.autorizacao
  end

  def pode_gerir?(alvo)
    @minha.pode_acao?(:gerenciar_usuarios) && (@minha.dono? || !alvo.autorizacao.dono?)
  end

  def erros_de_atribuicao(alvo, funcao, acessos_extras)
    return [ "choose a função" ] unless funcao

    nova = Autorizacao.new(funcao, acessos_extras)
    erros_de_dono(alvo, nova).presence || erros_acima_do_gestor(nova)
  end

  def erros_para_desativar(alvo)
    return [ "you can't deactivate yourself" ] if alvo == @gestor
    return [ "only a dono can deactivate a dono" ] unless pode_gerir?(alvo)
    return [ "#{alvo.nome} is the only active dono; the empresa must keep one" ] if ultimo_dono?(alvo)

    []
  end

  private

  def erros_de_dono(alvo, nova)
    return [ "only a dono can give the Dono função" ] if nova.dono? && !@minha.dono?
    return [ "#{alvo.nome} is the only active dono; the empresa must keep one" ] if !nova.dono? && ultimo_dono?(alvo)

    []
  end

  # A dono may give anything; anyone else, at most what they have.
  def erros_acima_do_gestor(nova)
    return [] if @minha.dono?

    areas = Autorizacao::AREAS.select { |area| nova.nivel(area) > @minha.nivel(area) }
    acoes = Autorizacao::ACOES.select { |acao| nova.pode_acao?(acao) && !@minha.pode_acao?(acao) }
    (areas + acoes).map { |item| "you can't give more than you have (#{item})" }
  end

  def ultimo_dono?(alvo)
    return false unless alvo.persisted? && alvo.ativo? && alvo.autorizacao.dono?

    User.ativos.joins(vinculos: :funcao).where(funcoes: { dono: true }).where.not(id: alvo.id).none?
  end
end
