# The tags that subscribe a page to its live updates (Etapa 2.8, 3b), always
# through AoVivoChannel — never `turbo_stream_from`, whose names Turbo signs
# for its own channel, which checks no one.
module CanaisAoVivoHelper
  # The gallery cards this person sees. Usage: <%= canal_dos_cartoes %>
  def canal_dos_cartoes
    assinatura_ao_vivo(CanaisAoVivo.cartoes(Current.user.cliente))
  end

  # Usage: <%= canal_do_registro(@pedido) %>
  def canal_do_registro(registro)
    assinatura_ao_vivo(CanaisAoVivo.do_registro(registro))
  end

  private

  def assinatura_ao_vivo(nome)
    tag.turbo_cable_stream_source(channel: "AoVivoChannel", "signed-stream-name": CanaisAoVivo.assinar(nome))
  end
end
