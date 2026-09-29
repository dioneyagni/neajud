# Stands in for DxfOrganizationService (Node + ImageMagick) in specs of code
# that takes an `organizador` dependency. Records what it was asked to do.
#
# Usage: PreparacaoTamanhosJob.organizador = FakeOrganizadorDxf.new
class FakeOrganizadorDxf
  attr_reader :chamadas

  def initialize(falha: nil)
    @falha = falha
    @chamadas = []
  end

  def call(arquivo)
    registrar(:redetectar, arquivo)
  end

  def generate_tamanho_previews(arquivo)
    registrar(:previews, arquivo)
  end

  private

  def registrar(acao, arquivo)
    raise @falha if @falha

    @chamadas << [ acao, arquivo.id ]
  end
end
