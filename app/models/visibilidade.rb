# Who sees which records (Etapa 2.8, decided 10/10/2026): everyone uses the
# same screens, and this is the single place that says, per model, which rows
# a person may see — the empresa's team sees everything; a "cliente final"
# (a vínculo tied to a Client) sees only what is that client's. The Funções
# grid (Autorizacao) says what a person may *do*; this says *whose* records.
#
# Between empresas nothing is filtered here: each empresa is its own instance
# (docs/plano.md Fase 3). Configurable visibility per kind (open/closed, the
# Fase 9 sharing format) builds on these rules in 2.8 (3/5).
#
# A model without a rule raises: a new model must say who sees it.
#
# Usage: Visibilidade.new(Current.user&.cliente).escopo(Pedido) # => Pedido.where(client: …) or Pedido.all
class Visibilidade
  # The client's own rows, by the path from each model to its client.
  DO_CLIENTE = {
    "Client" => ->(c) { Client.where(id: c.id) },
    "Pedido" => ->(c) { Pedido.where(client_id: c.id) },
    "Molde" => ->(c) { Molde.where(client_id: c.id) },
    "MovimentoEstoque" => ->(c) { MovimentoEstoque.where(client_id: c.id) },
    # Artes are the client's; a corte is when linked to one of its moldes.
    "Arquivo" => ->(c) { Arquivo.where(client_id: c.id).or(Arquivo.where(id: ArquivoMolde.where(molde_id: Molde.where(client_id: c.id)).select(:arquivo_id))) },
    "Arte" => ->(c) { Arte.where(id: Arquivo.where(client_id: c.id).select(:arte_id)) },
    "Referencia" => ->(c) { Referencia.where(molde_id: Molde.where(client_id: c.id)) },
    "Tamanho" => ->(c) { Tamanho.where(arquivo_id: DO_CLIENTE["Arquivo"].call(c).select(:id)) },
    "ArquivoVersion" => ->(c) { ArquivoVersion.where(arquivo_id: DO_CLIENTE["Arquivo"].call(c).select(:id)) },
    "ItemPedido" => ->(c) { ItemPedido.where(pedido_id: Pedido.where(client_id: c.id)) },
    "BaixaProducao" => ->(c) { BaixaProducao.where(pedido_id: Pedido.where(client_id: c.id)) },
    "AprovacaoArte" => ->(c) { AprovacaoArte.where(arte_id: DO_CLIENTE["Arte"].call(c).select(:id)) },
    "SolicitacaoAprovacao" => ->(c) { SolicitacaoAprovacao.where(arte_id: DO_CLIENTE["Arte"].call(c).select(:id)) },
    "FaixaDePreco" => ->(c) { FaixaDePreco.where(molde_id: Molde.where(client_id: c.id)) }
  }.freeze
  # The same for everyone: the official catalog and the empresa's lists.
  COMUNS = %w[Produto Modelo Peca MateriaPrima GrupoMaterial CorMaterial].freeze
  # The team's own business: a cliente final sees none of it.
  DA_EQUIPE = %w[User Funcao Vinculo ExclusaoLog Empresa].freeze

  def initialize(cliente)
    @cliente = cliente
  end

  # Usage: visibilidade.escopo(Molde).ativos.order(:nome)
  def escopo(modelo)
    nome = modelo.name
    regra = DO_CLIENTE[nome]
    raise ArgumentError, "#{nome} has no visibility rule; expected one of #{(DO_CLIENTE.keys + COMUNS + DA_EQUIPE).sort.join(", ")}" unless regra || COMUNS.include?(nome) || DA_EQUIPE.include?(nome)
    return modelo.all if @cliente.nil? || COMUNS.include?(nome)
    return modelo.none if DA_EQUIPE.include?(nome)

    regra.call(@cliente)
  end

  def cliente?
    !@cliente.nil?
  end
end
