class FilaDeProducao
  # One resource's lane in a turno (Máquinas 2/5a, the 4B mockup): its
  # hours there and its pieces, other sectors' included.
  # Usage: turno.raias.first.ocupadas # => 0.5
  RaiaDoTurno = Struct.new(:recurso, :livres, :pecas, keyword_init: true) do
    def ocupadas
      pecas.sum { |_, trecho| trecho.horas }
    end
  end
end
