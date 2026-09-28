module FuncoesHelper
  ROTULOS_AREA = {
    "pedidos" => "Pedidos", "clientes" => "Clientes", "artes" => "Artes",
    "catalogo" => "Catálogo", "estoque" => "Estoque", "lixeira" => "Lixeira"
  }.freeze
  ROTULOS_NIVEL = { 0 => "—", 1 => "Ver", 2 => "Editar", 3 => "Excluir" }.freeze
  # Lixeira's level 2 restores (Autorizacao::NIVEL_MAXIMO).
  ROTULOS_NIVEL_LIXEIRA = { 0 => "—", 1 => "Ver", 2 => "Restaurar" }.freeze
  ROTULOS_ACAO = {
    "baixar_producao" => "Baixar arquivos de produção", "gerenciar_usuarios" => "Gerenciar usuários",
    "aprovar_arte" => "Enviar e registrar aprovação de arte"
  }.freeze

  # [label, value] pairs for an área's level select on the Funções grid.
  # Usage: options_for_select(opcoes_de_nivel("lixeira"), funcao.niveis["lixeira"])
  def opcoes_de_nivel(area)
    rotulos = area == "lixeira" ? ROTULOS_NIVEL_LIXEIRA : ROTULOS_NIVEL
    rotulos.map { |valor, rotulo| [ rotulo, valor ] }
  end

  # Usage: rotulo_de_nivel("lixeira", 2) # => "Restaurar"
  def rotulo_de_nivel(area, nivel)
    (area == "lixeira" ? ROTULOS_NIVEL_LIXEIRA : ROTULOS_NIVEL).fetch(nivel.to_i)
  end
end
