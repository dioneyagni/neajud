# The live updates' stream names, and who may listen to each (Etapa 2.8, 3b,
# decided 11/10/2026). Turbo's own channel only checks that a name is signed,
# and a signed name is valid forever for whoever holds it; these names are
# signed with our own verifier, so only AoVivoChannel takes them, and it asks
# `permitido?` on every subscription.
#
# Names carry uuids, never Turbo's default `gid://…/Arquivo/232` (the integer
# id left the server inside the page — "Public identifiers are uuids"):
#
#   cartoes:equipe          the gallery cards, for the team
#   cartoes:<client uuid>   the cards a cliente final of that client sees
#   arquivo:<uuid>          refresh of an arquivo's page
#   pedido:<uuid>           refresh of a pedido's page
#
# Usage: CanaisAoVivo.recarregar(pedido)
module CanaisAoVivo
  EQUIPE = "cartoes:equipe".freeze
  REGISTROS = { "arquivo" => "Arquivo", "pedido" => "Pedido" }.freeze

  module_function

  # The gallery's stream for this person: the team's, or its client's.
  # Usage: CanaisAoVivo.cartoes(Current.user.cliente) # => "cartoes:8f3a…"
  def cartoes(cliente)
    cliente ? "cartoes:#{cliente.uuid}" : EQUIPE
  end

  # Usage: CanaisAoVivo.do_registro(arquivo) # => "arquivo:8f3a…"
  def do_registro(registro)
    prefixo = REGISTROS.key(registro.class.name)
    raise ArgumentError, "#{registro.class.name} has no live stream; expected one of #{REGISTROS.values.join(", ")}" unless prefixo

    "#{prefixo}:#{registro.uuid}"
  end

  # The card's DOM id, a broadcast's target (dom_id used the integer id).
  # Usage: CanaisAoVivo.id_do_cartao(arquivo) # => "arquivo_8f3a…"
  def id_do_cartao(arquivo)
    "arquivo_#{arquivo.uuid}"
  end

  # Every stream a card goes to: the team's, and each client that sees the
  # file — its arte's client, or a client of a molde the corte is linked to,
  # each by its own Visibilidade (a closed cortes kind keeps the corte away);
  # a work in the coleção geral, every client (Etapa 2.5a).
  # Usage: CanaisAoVivo.dos_cartoes_de(arquivo) # => ["cartoes:equipe", "cartoes:8f3a…"]
  def dos_cartoes_de(arquivo)
    candidatos = Client.where(id: arquivo.client_id).or(Client.where(id: arquivo.moldes.select(:client_id)))
    candidatos = Client.all if arquivo.arte&.no_catalogo
    [ EQUIPE ] + candidatos.select { |c| Visibilidade.new(c).escopo(Arquivo, colecao_geral: true).exists?(id: arquivo.id) }.map { |c| cartoes(c) }
  end

  # Morph-refreshes the record's page for whoever has it open.
  def recarregar(registro)
    Turbo::StreamsChannel.broadcast_refresh_to(do_registro(registro))
  end

  # Usage: CanaisAoVivo.permitido?(user, "pedido:8f3a…") # => false for another client's
  def permitido?(user, nome)
    tipo, chave = nome.to_s.split(":", 2)
    return false if chave.blank?
    return chave == (user.cliente&.uuid || "equipe") if tipo == "cartoes"

    modelo = REGISTROS[tipo]
    # A page shows what it reads: the coleção geral too (Etapa 2.5a).
    !modelo.nil? && Visibilidade.new(user.cliente).escopo(modelo.constantize, colecao_geral: true).exists?(uuid: chave)
  end

  def assinar(nome)
    verificador.generate(nome)
  end

  # nil when the signature doesn't match (tampered, or signed by Turbo).
  def ler(assinado)
    verificador.verified(assinado)
  end

  def verificador
    Rails.application.message_verifier("canais_ao_vivo")
  end
end
