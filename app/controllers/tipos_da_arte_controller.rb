# The kind of work an arte is, from its page (Etapa 2.5a, decided 12/10/2026):
# changed while no pedido uses it — a DTF or a corrida takes a new number —
# and "Entra no catálogo", the team's: it opens the work to every client.
class TiposDaArteController < ApplicationController
  exige :artes, :editar
  exige_equipe only: :catalogo
  before_action :set_arquivo

  # Usage: PATCH /arquivos/:arquivo_id/tipo_da_arte, tipo=dtf
  def update
    arte = @arquivo.arte
    return redirect_to @arquivo, alert: "#{arte.titulo}: #{arte.errors.full_messages.to_sentence}" unless arte.trocar_tipo!(params[:tipo])

    redirect_to @arquivo, notice: "#{arte.titulo} is now #{arte.rotulo_do_tipo}#{" (#{arte.codigo})" if arte.codigo}."
  end

  # Usage: PATCH /arquivos/:arquivo_id/tipo_da_arte/catalogo, no_catalogo=1
  def catalogo
    arte = @arquivo.arte
    canais_antes = CanaisAoVivo.dos_cartoes_de(arte.principal)
    return redirect_to @arquivo, alert: "#{arte.titulo}: #{arte.errors.full_messages.to_sentence}" unless arte.update(no_catalogo: params[:no_catalogo] == "1")

    # Who sees the card changed: every client's gallery follows.
    @arquivo.redesenhar_cartao!(canais_antes)
    redirect_to @arquivo, notice: arte.no_catalogo ? "#{arte.titulo} is in the catálogo: every client sees it." : "#{arte.titulo} left the catálogo: only its client sees it."
  end

  private

  def set_arquivo
    @arquivo = visiveis(Arquivo).ativos.where(category: "artes").por_uuid!(params[:arquivo_id])
  end
end
