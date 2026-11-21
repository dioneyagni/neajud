# How long the cutting machine takes for some Corte lines (Painel 2/4a2,
# decided 06/11/2026, A2–A6):
#
#   per piece: the cut line (contour + layers Cut) ÷ the speed, plus the
#              holes (layers Hole) × the punch     — Tamanho#corte_da_maquina
#   + the fabric's meters × the preparo (each meter is laid and prepared)
#   + the pieces ÷ the recolhimento (pieces gathered per minute)
#   + each change of material × the troca: in the lines, and from the
#     material the machine ended on (`anterior`: the pedido before it in
#     the queue, Painel 2/4b) when it isn't one of theirs
#
# Máquinas 1/5 (Q8a): with several machines doing the Corte do calçado,
# each with its parameters, they share the load: the stage takes
# 1 ÷ Σ(1 ÷ each one's time) — the same as summing their m/h. The queue per
# machine (Máquinas 2/5) replaces it.
#
# Its materials go one after the other, the one already on the machine
# first. A size with no measure counts nothing and is named in sem_medida,
# so a short time never looks real.
#
# Usage: tempo = TempoDoCorte.call(linhas, RitmoProducao.de("calcado", "corte"), anterior: oxford)
#        [ tempo.horas, tempo.ultimo_material, tempo.sem_medida ] # => [1.42, helanca, []]
class TempoDoCorte
  Tempo = Struct.new(:segundos, :ultimo_material, :sem_medida, keyword_init: true) do
    def horas
      segundos / 3600.0
    end
  end

  # linhas: LinhasDeProducao lines of a Corte stage.
  def self.call(linhas, ritmo, anterior: nil)
    new(linhas, ritmo, anterior).call
  end

  def initialize(linhas, ritmo, anterior)
    @linhas = linhas
    @ritmo = ritmo
    @anterior = anterior
    @anotacoes = {}
  end

  def call
    materiais = ordem_dos_materiais
    Tempo.new(segundos: juntas(@ritmo.fontes_do_corte.map { |fonte| segundos_com(fonte, materiais) }),
              ultimo_material: materiais.last || @anterior, sem_medida: sem_medida)
  end

  private

  # fonte: whose parameters (ParametrosDoCorte) — the ritmo's or a machine's.
  def segundos_com(fonte, materiais)
    maquina(fonte) + preparo(fonte) + recolhimento(fonte) + trocas(materiais) * fonte.parametro_do_corte(:troca_min) * 60
  end

  # Machines cutting at once: nothing to cut takes no time on any of them.
  def juntas(segundos)
    return 0.0 unless segundos.all?(&:positive?)

    1.0 / segundos.sum { |cada| 1.0 / cada }
  end

  def maquina(fonte)
    @linhas.sum do |linha|
      corte = corte_de(linha)
      corte ? linha.pecas * (corte.linha_mm / fonte.parametro_do_corte(:velocidade_mm_s) + corte.furos * fonte.parametro_do_corte(:pinca_s)) : 0
    end
  end

  def preparo(fonte)
    @linhas.sum { |linha| linha.esperado.to_f } * fonte.parametro_do_corte(:preparo_min) * 60
  end

  def recolhimento(fonte)
    @linhas.sum(&:pecas).to_f / fonte.parametro_do_corte(:recolhimento_pecas_min) * 60
  end

  def ordem_dos_materiais
    materiais = @linhas.filter_map(&:materia_prima).uniq
    materiais.include?(@anterior) ? [ @anterior ] + (materiais - [ @anterior ]) : materiais
  end

  def trocas(materiais)
    return 0 if materiais.empty?

    materiais.size - 1 + (@anterior && materiais.first != @anterior ? 1 : 0)
  end

  def sem_medida
    @linhas.reject { |linha| corte_de(linha) }.map { |linha| linha.tamanho.nome }.uniq
  end

  def corte_de(linha)
    linha.tamanho.corte_da_maquina(anotacoes_de(linha.tamanho.arquivo))
  end

  # The corte's layer types by color (CutLayer), read once per corte.
  def anotacoes_de(arquivo)
    @anotacoes[arquivo.id] ||= Array(arquivo.approved_version&.cut_layers).to_h { |camada| [ camada.color.upcase, camada.annotation ] }
  end
end
