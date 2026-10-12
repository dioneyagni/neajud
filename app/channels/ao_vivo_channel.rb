# Every live update of the app runs here (Etapa 2.8, 3b): Turbo's own channel
# trusts any signed name; this one also asks CanaisAoVivo whether the
# connection's user may listen — the team's cards only for the team, a
# client's only for its people, a page's only while Visibilidade shows it.
class AoVivoChannel < ActionCable::Channel::Base
  def subscribed
    nome = CanaisAoVivo.ler(params[:signed_stream_name])
    return reject unless nome && CanaisAoVivo.permitido?(current_user, nome)

    stream_from nome
  end
end
