# Stands in for ProgramadoNaFila (Painel 3/4b) in specs of code that takes a
# `programado`: the hours the photos programmed and are still to do, per
# sector (today's) or per sector and turno name.
#
# Usage: LinhaDoTempo.call(…, programado: FakeProgramadoNaFila.new(dia: { "impressao" => 8.0 }))
class FakeProgramadoNaFila
  def initialize(dia: {}, turno: {})
    @dia, @turno = dia, turno
  end

  def pendentes_do_dia(setor)
    @dia[setor]
  end

  def pendentes_do_turno(setor, ocorrencia)
    @turno[[ setor, ocorrencia.turno.nome ]]
  end

  def adiamento(_vez)
    nil
  end
end
