# What a cliente final sees, by kind (Etapa 2.8, 3a; decided 10/10/2026):
# the empresa's default grid (Empresa#visibilidade_cliente, the dono's,
# /visibilidade) and each client's exceptions (Client#visibilidade, on the
# client's page, "gerenciar usuários"). A kind open applies to everything of
# that kind, existing and future (no per-item exceptions yet — Fase 9).
#
# Always open, never a kind: the artes' previews and versions (the client
# approves them). Never open: costs and margin — "valores" is the price per
# pair only.
#
# Usage: TiposParaCliente.abertos_para(client) # => ["pedidos", "moldes", "estoque"]
class TiposParaCliente
  PADRAO = {
    "pedidos" => true,  # pedidos and their progress
    "moldes" => true,   # moldes and referências
    "estoque" => true,  # its stock movements
    "original" => false, # downloading the original files
    "cortes" => false,  # the cortes (DXF) and their sizes
    "valores" => false  # the price per pair
  }.freeze
  TIPOS = PADRAO.keys.freeze

  # The empresa's grid, then the client's exceptions over it.
  # Usage: TiposParaCliente.abertos_para(client, empresa: Empresa.atual)
  def self.abertos_para(client, empresa: Empresa.atual)
    grade = PADRAO.merge(empresa&.visibilidade_cliente.to_h).merge(client&.visibilidade.to_h)
    TIPOS.select { |tipo| grade[tipo] == true }
  end

  # The empresa's grid alone (what an exception departs from).
  # Usage: TiposParaCliente.padrao_da_empresa(Empresa.atual)["cortes"] # => false
  def self.padrao_da_empresa(empresa)
    PADRAO.merge(empresa&.visibilidade_cliente.to_h.slice(*TIPOS))
  end

  # Shape check for both columns: kind => true/false.
  # Usage: TiposParaCliente.erros({ "cortes" => "sim" }) # => ["invalid value \"sim\" for cortes; expected true or false"]
  def self.erros(grade)
    grade.to_h.flat_map do |tipo, aberto|
      next [ "unknown kind #{tipo.inspect}; expected one of #{TIPOS.join(", ")}" ] unless TIPOS.include?(tipo.to_s)
      next [] if [ true, false ].include?(aberto)

      [ "invalid value #{aberto.inspect} for #{tipo}; expected true or false" ]
    end
  end

  # Form values ("1"/"0"; "padrao" for an exception that follows the grid)
  # into the stored shape. Usage: TiposParaCliente.ler({ "cortes" => "1", "pedidos" => "padrao" }) # => { "cortes" => true }
  def self.ler(valores)
    valores.to_h.each_with_object({}) do |(tipo, valor), grade|
      next if valor.to_s == "padrao"

      grade[tipo.to_s] = { "1" => true, "0" => false }.fetch(valor.to_s, valor)
    end
  end
end
