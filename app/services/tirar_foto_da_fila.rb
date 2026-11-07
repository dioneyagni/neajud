# Takes the photo of the turno under way (Painel 3/4b, decided 07/11/2026,
# Q2a): the whole queue as FilaDeProducao computes it now, then the virada
# against the photo before (ViradaDaFila), then deletes the photos past 7
# days. Nothing when no turno is on or it already has its photo — the
# unique index settles two runs at once. FotoDaFilaJob calls it every 5
# minutes; a turno while the server was off has no photo.
#
# Usage: TirarFotoDaFila.call                       # => the FotoDaFila, or nil
#        TirarFotoDaFila.call(agora: Time.zone.parse("2026-11-04 13:00"))
class TirarFotoDaFila
  # aguardando: the missing materials (AguardandoMaterial), read when not given.
  def self.call(agora: Time.current, calendario: CalendarioDeProducao.new, aguardando: nil)
    ocorrencia = calendario.agora(agora)
    return if ocorrencia.nil? || FotoDaFila.do_turno(ocorrencia)

    new(agora, calendario, ocorrencia, aguardando).call
  end

  def initialize(agora, calendario, ocorrencia, aguardando)
    @agora, @calendario, @ocorrencia, @aguardando = agora, calendario, ocorrencia, aguardando
  end

  def call
    fila = FilaDeProducao.call(agora: @agora, calendario: @calendario, aguardando: @aguardando)
    anterior = FotoDaFila.where(inicio: ...@ocorrencia.inicio).order(:inicio).last
    foto = FotoDaFila.transaction do
      FotoDaFila.create!(turno: @ocorrencia.turno, data: @ocorrencia.data, inicio: @ocorrencia.inicio, fim: @ocorrencia.fim).tap do |nova|
        guardar(nova, fila)
        ViradaDaFila.call(anterior, nova, fila) if anterior
      end
    end
    FotoDaFila.vencidas(@agora).destroy_all
    CanaisAoVivo.avisar_fila
    foto
  rescue ActiveRecord::RecordNotUnique
    nil
  end

  private

  def guardar(foto, fila)
    linhas = fila.pedidos.flat_map do |pedido|
      previsao = fila.previsao(pedido)
      previsao.vezes.map { |vez| linha_da_vez(foto, vez, previsao.fim) }
    end
    VezDaFoto.insert_all(linhas) if linhas.any?
  end

  def linha_da_vez(foto, vez, previsao)
    { foto_da_fila_id: foto.id, pedido_id: vez.pedido.id, etapa: vez.etapa.chave, setor: vez.setor, posicao: vez.posicao,
      fim: vez.fim, previsao: previsao, trechos: vez.trechos.map { |trecho| { "inicio" => trecho.inicio.iso8601, "fim" => trecho.fim.iso8601 } } }
  end
end
