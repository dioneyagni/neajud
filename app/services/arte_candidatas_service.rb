# Artes that can fill a pending piece of a pedido item, in the order the user
# asked for:
#   1. do cliente, sem peça — this modelo's first, then other modelos of the
#      same client (choosing one of those moves it, after confirmation);
#   2. do cliente, sem modelo;
#   3. sem cliente.
# Artes already printed on another peça are left out: linking them would not
# change the peça they resolve to. An arte whose resolved peça is the pending
# one (e.g. no modelo yet) is a candidate.
#
# Usage: ArteCandidatasService.call(peca_row)
#   # => [#<Grupo chave=:cliente_sem_peca titulo="…" artes=[…]>, …]
class ArteCandidatasService
  Grupo = Struct.new(:chave, :titulo, :artes, keyword_init: true)

  def self.call(peca_row)
    new(peca_row).call
  end

  def initialize(peca_row)
    @peca = peca_row.peca
    @modelo = peca_row.item_pedido.arquivo.modelo
    @client_id = @modelo&.client_id
  end

  def call
    return [] unless @modelo

    [
      Grupo.new(chave: :cliente_sem_peca, titulo: "Do cliente, sem peça", artes: cliente_sem_peca),
      Grupo.new(chave: :cliente_sem_modelo, titulo: "Do cliente, sem modelo", artes: cliente_sem_modelo),
      Grupo.new(chave: :sem_cliente, titulo: "Sem cliente", artes: sem_cliente)
    ]
  end

  # Usage: ArteCandidatasService.new(peca_row).candidata?(arte) # => true
  def candidata?(arte)
    call.any? { |grupo| grupo.artes.include?(arte) }
  end

  private

  def artes
    Arquivo.ativos.where(category: "artes").includes(:modelo, :approved_version, :peca, tamanho: { arquivo: :peca })
  end

  def cliente_sem_peca
    artes.where(client_id: @client_id).where.not(modelo_id: nil).sem_peca_resolvida
         .sort_by { |arte| [ arte.modelo_id == @modelo.id ? 0 : 1, arte.modelo.nome, arte.filename ] }
  end

  def cliente_sem_modelo
    livres(artes.where(client_id: @client_id, modelo_id: nil))
  end

  def sem_cliente
    livres(artes.where(client_id: nil))
  end

  # Without peça, or already on the pending peça.
  def livres(scope)
    scope.order(:filename).select { |arte| [ nil, @peca ].include?(arte.resolved_peca) }
  end
end
