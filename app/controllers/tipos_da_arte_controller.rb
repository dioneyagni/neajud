# The kind of work an arte is, from its page (Etapa 2.5a, decided 12/10/2026):
# changed while no pedido uses it — a DTF or a corrida takes a new number —
# and "Entra no catálogo", the team's: it opens the work to every client.
# A DTF's spacing on the film is the team's too (Etapa 2.6a).
class TiposDaArteController < ApplicationController
  exige :artes, :editar
  exige_equipe only: %i[catalogo espacamento]
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

  # A cor lisa's optional material (Etapa 2.5b): not in its name.
  # Usage: PATCH /arquivos/:arquivo_id/tipo_da_arte/material, materia_prima_uuid=…
  def material
    arte = @arquivo.arte
    arte.materia_prima_uuid = params[:materia_prima_uuid]
    return redirect_to @arquivo, alert: "#{arte.titulo}: #{arte.errors.full_messages.to_sentence}" unless arte.save

    redirect_to @arquivo, notice: "Material of #{arte.titulo}: #{arte.materia_prima&.nome_completo || "none"}."
  end

  # A DTF's own space between its copies on the film (Etapa 2.6a, decided
  # 13/10/2026): the team's, never shown to the cliente final; blank goes
  # back to the dono's default.
  # Usage: PATCH /arquivos/:arquivo_id/tipo_da_arte/espacamento, espacamento_mm=2,5
  def espacamento
    arte = @arquivo.arte
    arte.espacamento_mm = params[:espacamento_mm].to_s.strip.tr(",", ".").presence
    return redirect_to @arquivo, alert: "#{arte.titulo}: #{arte.errors.full_messages.to_sentence}" unless arte.save

    redirect_to @arquivo, notice: "Spacing of #{arte.titulo}: #{helpers.number_with_precision(arte.espacamento_efetivo_mm, precision: 2, separator: ",", strip_insignificant_zeros: true)} mm#{" (the default)" unless arte.espacamento_mm}."
  end

  private

  def set_arquivo
    @arquivo = visiveis(Arquivo).ativos.where(category: "artes").por_uuid!(params[:arquivo_id])
  end
end
