# Stands in for EncaixeDoTamanho (Node) in specs of code that takes an
# `encaixe` dependency. Records each size × width it was asked about.
#
# Usage: MetrosPorPecaJob.encaixe = FakeEncaixe.new
class FakeEncaixe
  attr_reader :chamadas

  def initialize
    @chamadas = []
  end

  def call(tamanho, largura_mm)
    @chamadas << [ tamanho.id, largura_mm ]
    0.02
  end
end
