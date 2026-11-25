class FilaDeProducao
  # A turno of a sector's queue (Painel 2/4b): its pieces, and since
  # Máquinas 2/5a a lane per resource (RaiaDoTurno) and the hours they have
  # summed. pecas, outras: [vez, trecho] — the sector's, and other sectors'
  # on its machines (Q1a).
  # Usage: fila.turnos_do_setor("impressao").first.ocupadas # => 1.5
  TurnoDaFila = Struct.new(:ocorrencia, :pecas, :outras, :raias, :livres, keyword_init: true) do
    def ocupadas
      (pecas + Array(outras)).sum { |_, trecho| trecho.horas }
    end

    # Lanes worth showing: some machine among them (a sector with none is one agenda, as before).
    def com_maquinas?
      Array(raias).any? { |raia| raia.recurso.maquina? }
    end
  end
end
