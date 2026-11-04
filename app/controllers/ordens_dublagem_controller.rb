# The Dublagens page (Dublagem 5a, decided 03-04/11/2026): the dublagens em
# aberto — what confirmed pedidos miss of each dublado made for the stock —
# and the ordens generated, done and cancelled. Seen with estoque ver; the
# operator who gives the production baixas generates, marks done and
# cancels (decision 3a, atualizar_producao). The team's only, as the
# construções.
class OrdensDublagemController < ApplicationController
  include NumeroDigitado
  exige :estoque, :ver, only: :index
  exige_acao :atualizar_producao, only: %i[create feita cancelar]
  exige_equipe

  ULTIMAS = 30

  def index
    movimentos = visiveis(MovimentoEstoque)
    ordens = visiveis(OrdemDublagem).includes(:client, :gerada_por, :feita_por, :cancelada_por, construcao: [ :materia_prima, { camadas: %i[materia_prima ligante] } ])
    @em_aberto = DublagensEmAberto.call(aguardando: AguardandoMaterial.call(movimentos), geradas: ordens.geradas)
    @geradas = ordens.geradas.order(:created_at)
    @feitas = ordens.feitas.order(feita_em: :desc).limit(ULTIMAS)
    @canceladas = ordens.canceladas.order(cancelada_em: :desc).limit(ULTIMAS)
    @saldos = SaldosDeEstoque.call(movimentos)
    @pedidos = visiveis(Pedido).where(id: @em_aberto.flat_map(&:pedido_ids)).index_by(&:id)
  end

  # Usage: POST /dublagens, construcao_uuid=…, metros=23,5
  def create
    construcao = visiveis(Construcao).por_uuid!(params[:construcao_uuid])
    ordem = visiveis(OrdemDublagem).new(construcao: construcao, metros: decimal_digitado(params[:metros]), gerada_por: Current.user)
    return redirect_to dublagens_path, notice: "Ordem de dublagem ##{ordem.uuid.first(8)} gerada: #{helpers.metros(ordem.metros)} de #{construcao.nome}." if ordem.save

    redirect_to dublagens_path, alert: ordem.errors.full_messages.to_sentence
  end

  # Usage: PATCH /dublagens/:uuid/feita, metros=22,5 (the real meters)
  def feita
    ordem = ordem_por_uuid(params[:id])
    ordem.marcar_feita!(metros: decimal_digitado(params[:metros]), user: Current.user)
    redirect_to dublagens_path, notice: "Ordem ##{ordem.uuid.first(8)} feita: entraram #{helpers.metros(ordem.metros_feitos)} de #{ordem.construcao.nome}."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to dublagens_path, alert: e.record.errors.full_messages.to_sentence
  end

  def cancelar
    ordem = ordem_por_uuid(params[:id])
    ordem.cancelar!(user: Current.user)
    redirect_to dublagens_path, notice: "Ordem ##{ordem.uuid.first(8)} cancelada."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to dublagens_path, alert: e.record.errors.full_messages.to_sentence
  end

  private

  def ordem_por_uuid(uuid)
    visiveis(OrdemDublagem).por_uuid!(uuid)
  end
end
