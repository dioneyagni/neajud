# Undoes a production baixa (Etapa 2.2, 3/3; decided 07/10/2026): kept in the
# history with who undid it and when, its lines open again. Refused once the
# pedido is delivered, and while a stage locked on it has a baixa on those
# lines (undo the Estamparia before the Corte it waited for). Undoing the
# last one takes the pedido back to confirmed.
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

    dependente = etapas_que_esperam.find { |etapa| cobre_linhas_desta?(etapa) }
    "Undo #{dependente.nome}'s baixa of these lines first: it waited for this one." if dependente
  end

  def etapas_que_esperam
    EtapasProducao.do_tipo(@pedido.tipo).select { |etapa| etapa.trava.include?(@baixa.etapa) }
  end

  # Does a standing baixa of the waiting stage cover a line that waited for this one?
  def cobre_linhas_desta?(etapa)
    feitas = @pedido.baixas_producao.vigentes.da_etapa(etapa.chave).feitas
    corte = EtapasProducao.etapa(@pedido.tipo, @baixa.etapa).linhas == "corte"
    LinhasDeProducao.call(@pedido, etapa).any? do |linha|
      feitas.include?(linha.chave) && @baixa.linhas.include?(corte ? linha.corte_chave : linha.chave)
    end
  end
end
