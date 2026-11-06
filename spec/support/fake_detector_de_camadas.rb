# Stands in for DxfOrganizationService#deteccao (Node) in
# MedirCamadasDoCorte's spec: answers the detection it was given.
# Usage: MedirCamadasDoCorte.call(corte, detector: FakeDetectorDeCamadas.new("tamanhos" => [ … ]))
class FakeDetectorDeCamadas
  def initialize(deteccao)
    @deteccao = deteccao
  end

  attr_reader :deteccao
end
