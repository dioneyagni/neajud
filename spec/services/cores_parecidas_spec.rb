require "rails_helper"

# Etapa 2.5b (decided 12/10/2026): the nearest measured colors, a notice.
RSpec.describe CoresParecidas do
  def cor(hex)
    arquivo = create(:arquivo, category: "artes", arte: Arte.novo_do_tipo("cor_lisa"))
    l, a, b = MedidaDeCor.lab_do_hex(hex)
    arquivo.update!(approved_version: create(:arquivo_version, arquivo: arquivo, version_number: 1, status: :processed, lab_l: l, lab_a: a, lab_b: b, cor_hex: hex))
    arquivo.arte.tap { |arte| arte.batizar!([ l, a, b ]) }
  end

  it "lists the near ones by ΔE, each marked practically equal (≤ 1) or similar (≤ 3)" do
    laranja = cor("#EF4123")
    quase = cor("#EF4224")
    parecida = cor("#F04A2A")
    cor("#0071BB")
    resultado = described_class.call(laranja, candidatas: Arte.all)
    expect(resultado.map { |p| [ p.arte, p.grau ] }).to eq([ [ quase, :praticamente_igual ], [ parecida, :parecida ] ])
    expect(resultado.first.delta_e).to be < 1
  end

  it "compares only with the candidates given (the colors the person sees)" do
    laranja = cor("#EF4123")
    outra = cor("#EF4224")
    expect(described_class.call(laranja, candidatas: Arte.where.not(id: outra.id))).to eq([])
  end

  it "says whether any is near, for the card" do
    laranja = cor("#EF4123")
    expect(described_class.alguma?(laranja)).to be(false)
    cor("#EF4224")
    expect(described_class.alguma?(laranja)).to be(true)
  end

  it "skips a color in the trash and one not measured yet" do
    laranja = cor("#EF4123")
    cor("#EF4224").principal.excluir!(changed_by: "spec")
    create(:arquivo, category: "artes", arte: Arte.novo_do_tipo("cor_lisa"))
    expect(described_class.call(laranja, candidatas: Arte.all)).to eq([])
  end
end
