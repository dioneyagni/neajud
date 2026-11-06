# What some lines of a stage weigh in its rhythm's unit (Painel 2/4a2 and
# 2/4b): what RitmoMedido divides by a turno's hours and what the queue
# (FilaDeProducao) divides by the rhythm in use.
#   no `ritmo` in config/etapas_producao.yml — the lines' expected (the
#     baixa's measure: m, peças, unidades);
#   papel — the meters of paper of the same lines (the calçado's Estamparia);
#   maquina_de_corte — the cutting machine's hours (TempoDoCorte), from the
#     material it ended on (`anterior`).
#
# Usage: carga = CargaDaEtapa.call(pedido, etapa, linhas, ritmo)
#        [ carga.valor, carga.ultimo_material ] # => [3.2, tactel]
class CargaDaEtapa
  Carga = Struct.new(:valor, :ultimo_material, :sem_medida, keyword_init: true)

  # linhas: LinhasDeProducao lines of the stage; memoria: a Hash shared by
  # the calls of one page, so a pedido's paper lines are built once.
  def self.call(pedido, etapa, linhas, ritmo, anterior: nil, memoria: {})
    case etapa.ritmo
    when "papel" then Carga.new(valor: em_papel(pedido, etapa, linhas, memoria).sum { |linha| linha.esperado.to_f }, sem_medida: [])
    when "maquina_de_corte" then da_maquina(linhas, ritmo, anterior)
    else Carga.new(valor: linhas.sum { |linha| linha.esperado.to_f }, sem_medida: [])
    end
  end

  # The same lines, their expected the paper's meters.
  def self.em_papel(pedido, etapa, linhas, memoria)
    chaves = linhas.to_set(&:chave)
    todas = memoria[[ :papel, pedido.id, etapa.chave ]] ||= LinhasDeProducao.call(pedido, etapa.dup.tap { |em_papel| em_papel.esperado = "papel" })
    todas.select { |linha| chaves.include?(linha.chave) }
  end

  def self.da_maquina(linhas, ritmo, anterior)
    tempo = TempoDoCorte.call(linhas, ritmo, anterior: anterior)
    Carga.new(valor: tempo.horas, ultimo_material: tempo.ultimo_material, sem_medida: tempo.sem_medida)
  end
  private_class_method :em_papel, :da_maquina
end
