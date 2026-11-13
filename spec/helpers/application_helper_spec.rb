require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#autor_do_log" do
    it "names the user, falling back to the IP of older logs" do
      com_user = ExclusaoLog.new(user: build(:user, nome: "Ana"), changed_by: "10.0.0.1")
      so_ip = ExclusaoLog.new(changed_by: "10.0.0.1")
      expect([ helper.autor_do_log(com_user), helper.autor_do_log(so_ip), helper.autor_do_log(nil) ]).to eq([ "Ana", "10.0.0.1", nil ])
    end
  end

  # Dublagem 5b2a (Q1a): the stock in its material's unit.
  describe "#quantidade_do_material" do
    it "writes meters, or kg to the gram for a group counted in kg" do
      cor = CorMaterial.find_or_create_by!(nome: "Branco")
      oxford = MateriaPrima.create!(grupo_material: GrupoMaterial.create!(nome: "Oxford"), cor_material: cor, largura: "1.40 m", gramatura: "100g")
      cola = MateriaPrima.create!(grupo_material: GrupoMaterial.create!(nome: "Cola", unidade: "kg", atributos: { "consumo_g_m2" => true }), cor_material: cor, tipo: "filme", consumo_g_m2: 120)
      expect([ helper.quantidade_do_material(12.5, oxford), helper.quantidade_do_material(0.4815, cola), helper.quantidade_do_material(2, cola), helper.quantidade_do_material(3, nil) ])
        .to eq([ "12,5 m", "0,482 kg", "2 kg", "3 m" ])
      expect(helper.preco_da_unidade(18, cola)).to eq("$18.00/kg")
    end
  end
end
