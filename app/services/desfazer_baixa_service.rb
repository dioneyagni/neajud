# Undoes a production baixa (Etapa 2.2, 3/3; decided 07/10/2026): kept in the
# history with who undid it and when, its lines open again. Refused once the
# pedido is delivered, and while a stage locked on it has a baixa on those
# lines (undo the Estamparia before the Corte it waited for) — line by line
# since Dublagem 5b1c1 (LinhasDeProducao::Linha#esperas: DUB-C before the
# DUB-B it joined, in the same stage). Undoing the last one takes the pedido
# back to confirmed.
#
# Usage: DesfazerBaixaService.call(baixa, user: Current.user, changed_by: ip) # => nil, or the reason it can't
class DesfazerBaixaService
  def self.call(baixa, user:, changed_by: nil)
    new(baixa, user).call
  end

  def initialize(baixa, user)
    @baixa = baixa
    @pedido = baixa.pedido
    @user = user
  end

  def call
    erro = erro_ao_desfazer
    return erro if erro

    @baixa.update!(desfeita_em: Time.current, desfeita_por: @user)
    @pedido.voltar_a_confirmado!
    nil
  end

  private

  def erro_ao_desfazer
    return "This baixa was already undone." if @baixa.desfeita_em
    return "The pedido was delivered: its baixas no longer change." unless @pedido.em_producao?

    dependente = EtapasProducao.do_tipo(@pedido.tipo, pedido: @pedido).find { |etapa| cobre_linhas_desta?(etapa) }
    "Undo #{dependente.nome}'s baixa of these lines first: it waited for this one." if dependente
  end

  # Does a standing baixa of the stage cover a line that waited for this one?
  def cobre_linhas_desta?(etapa)
    feitas = @pedido.baixas_producao.vigentes.da_etapa(etapa.chave).feitas
    LinhasDeProducao.call(@pedido, etapa).any? do |linha|
      feitas.include?(linha.chave) && linha.esperas(etapa, @pedido.tipo).any? { |espera| espera.etapa == @baixa.etapa && @baixa.linhas.include?(espera.chave) }
    end
  end
end
