# The machines in a sector's queue (Máquinas 2/5a, the 4B mockup approved
# 21/11/2026): the lanes of the first turno, the Máquina column's colored
# chip and the filter by machine.
module MaquinasDaFilaHelper
  CORES_DAS_MAQUINAS = 6

  # The sector's machines in lane order (RecursosDaFila#do_setor).
  # Usage: maquinas_do_setor(fila, "estamparia").map(&:nome) # => ["Calandra 1", "Calandra 2"]
  def maquinas_do_setor(fila, setor)
    fila.recursos_do_setor(setor).filter_map { |recurso, _| recurso.maquina }
  end

  # Each machine's color, by its place among the sector's: { maquina id => 1..6 }.
  def cores_das_maquinas(maquinas)
    maquinas.each_with_index.to_h { |maquina, indice| [ maquina.id, (indice % CORES_DAS_MAQUINAS) + 1 ] }
  end

  # What a machine does, for its lane: "Calandra e Dublagem".
  def trabalhos_na_raia(maquina)
    maquina.trabalhos.map { |feito| TrabalhosDeMaquina.trabalho(feito.trabalho).nome }.to_sentence(last_word_connector: " e ", two_words_connector: " e ")
  end

  # A piece's place on the turno's lane, as left and width in % of the turno.
  # Usage: estilo_na_raia(trecho, ocorrencia) # => "left: 25.0%; width: 12.5%"
  def estilo_na_raia(trecho, ocorrencia)
    total = ocorrencia.fim - ocorrencia.inicio
    "left: #{((trecho.inicio - ocorrencia.inicio) / total * 100).round(2)}%; width: #{((trecho.fim - trecho.inicio) / total * 100).round(2)}%"
  end

  # "Now" on the lane, when the turno is under way: its left in %.
  def agora_na_raia(ocorrencia, agora)
    return unless ocorrencia.contem?(agora)

    ((agora - ocorrencia.inicio) / (ocorrencia.fim - ocorrencia.inicio) * 100).round(2)
  end

  # The hours a lane still has free in the turno: "2,8 h livres".
  def livres_da_raia(raia)
    "#{horas_da_fila([ raia.livres - raia.ocupadas, 0 ].max)} livres"
  end

  # A piece of another sector on the machine (Q1a): "dublando · #91be0d3f".
  def outra_na_raia(vez)
    "#{vez.etapa.nome.downcase} · ##{vez.pedido.uuid.first(8)}"
  end
end
