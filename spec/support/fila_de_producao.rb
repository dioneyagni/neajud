# The calendar and rhythms the queue specs run on (Painel 2/4b): one turno
# all day, every day, and calçado rhythms fast enough that a spec's pedido
# fits in minutes (its Corte is the machine's, with its defaults).
# Usage: turno_o_dia_todo; ritmos_do_calcado
module FilaDeProducaoSpec
  def turno_o_dia_todo(nome: "Dia")
    Turno.create!(nome: nome, inicio: "00:00", fim: "23:59", dias: (0..6).to_a)
  end

  def ritmos_do_calcado(por_hora: 1000)
    %w[impressao estamparia conferencia].each { |etapa| RitmoProducao.create!(tipo: "calcado", etapa: etapa, por_hora: por_hora) }
  end
end

RSpec.configure { |config| config.include FilaDeProducaoSpec }
