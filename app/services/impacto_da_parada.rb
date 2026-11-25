# What a stop does to the queue (Máquinas 3/5a, decided 24/11/2026): the
# queue again with it, against the one now (ComparacaoDaFila) — every
# pedido whose previsão gets worse, the ones that come to be late first.
# Saved with no confirmation (Q3a); what it found is kept in the stop
# (`impacto`, Q4a — for the bulletins to come). A piece held on a stopped
# machine, or started there, waits for it (Q2a): the list says so.
#
# Usage: impacto = ImpactoDaParada.call(parada, fila)
#        impacto.empurrados.count(&:passa_a_atrasar) # => 3
#        impacto.registro["pedidos"].first # => { "pedido_uuid" => "5d2f…", "passa_a_atrasar" => true, "motivo" => "presa na Calandra 2", … }
class ImpactoDaParada
  # empurrados: ComparacaoDaFila::Empurrado; esperam: the pieces held or
  # started on its machines; motivos: { pedido => "presa na Calandra 2" }.
  Impacto = Struct.new(:empurrados, :esperam, :motivos, :calculado_em, keyword_init: true) do
    # What the stop keeps.
    def registro
      { "calculado_em" => calculado_em.iso8601, "atrasam" => empurrados.count(&:passa_a_atrasar), "pioram" => empurrados.size, "esperam" => esperam,
        "pedidos" => empurrados.map { |e| ImpactoDaParada.linha(e, motivos[e.pedido]) } }
    end
  end

  # fila: the queue now (FilaDeProducao), without the stop.
  def self.call(parada, fila)
    depois = FilaDeProducao.call(**fila.entradas.merge(calendario: fila.calendario.com(parada)), ordens: fila.ordens, fixacoes: fila.fixacoes)
    paradas = parada.paradas_das_maquinas.map(&:maquina_id)
    presas = presas_em(depois, paradas)
    Impacto.new(empurrados: ComparacaoDaFila.empurrados(fila, depois), esperam: presas.size, calculado_em: fila.agora,
                motivos: presas.group_by(&:pedido).transform_values { |vezes| motivo(vezes.first) })
  end

  # Usage: ImpactoDaParada.linha(empurrado, "presa na Calandra 2") # => { "pedido_uuid" => …, "de" => …, "para" => …, … }
  def self.linha(empurrado, motivo)
    { "pedido_uuid" => empurrado.pedido.uuid, "prazo" => empurrado.prazo&.iso8601, "de" => empurrado.de.iso8601, "para" => empurrado.para&.iso8601,
      "passa_a_atrasar" => empurrado.passa_a_atrasar, "motivo" => motivo }.compact
  end

  # The pieces that can't leave a stopped machine: held there (2/5b) or
  # started on it (4/5a).
  def self.presas_em(fila, maquina_ids)
    return [] if maquina_ids.empty?

    fila.pedidos.flat_map { |pedido| fila.previsao(pedido).vezes }
        .select { |vez| maquina_ids.include?(vez.maquina&.id) && (vez.maquina_da_baixa || vez.fixacao) }
  end

  def self.motivo(vez)
    "#{vez.maquina_da_baixa ? "começada" : "presa"} na #{vez.maquina.nome}"
  end
  private_class_method :presas_em, :motivo
end
