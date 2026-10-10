# What a user may do (Etapa 0.5, 2/4): the level their função gives in each
# área, raised by the vínculo's acessos_extras, plus special actions. The dono
# função can do everything and is not editable. The single entry point for
# permissions — controllers (ControleDeAcesso) and views (pode?) ask here, so
# the engine can change (e.g. Action Policy for per-record rules) without
# touching them.
#
# Usage: Autorizacao.new(funcao, vinculo.acessos_extras).pode?(:pedidos, :editar)
class Autorizacao
  AREAS = %w[pedidos clientes artes catalogo estoque lixeira].freeze
  NIVEIS = { "nenhum" => 0, "ver" => 1, "editar" => 2, "excluir" => 3 }.freeze
  # Áreas whose scale stops earlier. Lixeira: 1 ver, 2 restaurar (asked for
  # 27/09/2026 so the dono can hand the trash to someone).
  NIVEL_MAXIMO = { "lixeira" => 2 }.freeze
  # atualizar_producao: give a production stage's baixa (Etapa 2.2, 2/3).
  # ver_valores: see and set prices per pair and costs (Etapa 2.4).
  ACOES = %w[baixar_producao atualizar_producao gerenciar_usuarios aprovar_arte ver_valores].freeze
  # Never given to a cliente final (Etapa 2.8, 2/5): the trash and the
  # factory's own actions. Costs and margin are never shown to a client; the
  # price per pair reaches him by the visibility's "Valores" (3/5).
  AREAS_DA_EQUIPE = %w[lixeira].freeze
  ACOES_DA_EQUIPE = %w[baixar_producao atualizar_producao gerenciar_usuarios ver_valores].freeze

  # Shape check shared by Funcao#niveis/acoes and Vinculo#acessos_extras.
  # Usage: Autorizacao.erros_da_grade({ "pedidos" => 2 }, []) # => []
  def self.erros_da_grade(niveis, acoes)
    erros = (niveis.to_h.keys.map(&:to_s) - AREAS).map { |area| "unknown área #{area.inspect}; expected one of #{AREAS.join(", ")}" }
    erros += niveis.to_h.flat_map { |area, nivel| erros_de_nivel(area.to_s, nivel) }
    erros + (Array(acoes).map(&:to_s) - ACOES).map { |acao| "unknown action #{acao.inspect}; expected one of #{ACOES.join(", ")}" }
  end

  # What a client's função or vínculo may not have, shared by Funcao and Vinculo.
  # Usage: Autorizacao.erros_para_cliente({ "lixeira" => 1 }, []) # => ["a client's access can't have lixeira"]
  def self.erros_para_cliente(niveis, acoes)
    areas = AREAS_DA_EQUIPE.select { |area| niveis.to_h.stringify_keys[area].to_i.positive? }
    (areas + (Array(acoes).map(&:to_s) & ACOES_DA_EQUIPE)).map { |item| "a client's access can't have #{item}; it is the team's" }
  end

  def self.nivel_maximo(area)
    NIVEL_MAXIMO.fetch(area.to_s, NIVEIS["excluir"])
  end

  def self.erros_de_nivel(area, nivel)
    return [] if nivel.is_a?(Integer) && nivel.between?(0, nivel_maximo(area))

    [ "invalid level #{nivel.inspect} for #{area}; expected 0 to #{nivel_maximo(area)}" ]
  end
  private_class_method :erros_de_nivel

  def initialize(funcao, acessos_extras = {})
    @funcao = funcao
    @extras = acessos_extras.to_h.stringify_keys
  end

  def dono?
    @funcao&.dono? || false
  end

  # Usage: autorizacao.nivel(:artes) # => 3
  def nivel(area)
    area = validar!(AREAS, area, "área")
    return self.class.nivel_maximo(area) if dono?

    [ @funcao&.niveis.to_h[area].to_i, @extras.fetch("niveis", {})[area].to_i ].max
  end

  # Usage: autorizacao.pode?(:clientes, :ver)
  def pode?(area, nivel)
    nivel(area) >= NIVEIS.fetch(validar!(NIVEIS.keys, nivel, "level"))
  end

  # Usage: autorizacao.pode_acao?(:baixar_producao)
  def pode_acao?(acao)
    acao = validar!(ACOES, acao, "action")
    dono? || Array(@funcao&.acoes).include?(acao) || Array(@extras["acoes"]).include?(acao)
  end

  private

  # A typo in a controller or view must fail loudly, never deny/allow quietly.
  def validar!(validos, valor, tipo)
    valor = valor.to_s
    return valor if validos.include?(valor)

    raise ArgumentError, "unknown #{tipo} #{valor.inspect}; expected one of #{validos.join(", ")}"
  end
end
