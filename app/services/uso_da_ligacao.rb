# The construções that join a ligação's pair (rede editável 2/2a, decided
# 10/11/2026): its page's "Onde ela é usada" and the warning before the
# trash (Q5a). Two layers one under the other whose groups are the pair, in
# any order; a ligação with a lado only where the superfície is on it. Read
# by groups, not through the network, so a ligação in the trash still finds
# its construções.
#
# Usage: UsoDaLigacao.new(ligacao, construcoes: visiveis(Construcao)).call # => [construcao, …]
class UsoDaLigacao
  def initialize(ligacao, construcoes:)
    @ligacao = ligacao
    @construcoes = construcoes
  end

  # The ones not in the trash, by name.
  def call
    @construcoes.ativos.includes(camadas: :materia_prima).order(:nome).select do |construcao|
      construcao.camadas_em_ordem.each_cons(2).any? { |acima, abaixo| junta?(acima, abaixo) }
    end
  end

  private

  def junta?(acima, abaixo)
    grupos = [ acima, abaixo ].map { |camada| camada.materia_prima.grupo_material_id }
    return false unless grupos.sort == [ @ligacao.grupo_a_id, @ligacao.grupo_b_id ].sort

    @ligacao.lado.nil? || (acima.superficie? && acima.lado == @ligacao.lado)
  end
end
