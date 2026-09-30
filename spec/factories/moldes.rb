FactoryBot.define do
  factory :molde do
    nome { "MyString" }
    client

    # The molde's own parts (Etapa 1.1, 3/5): create(:molde, partes: [lateral, lingua])
    transient do
      partes { [] }
    end

    after(:create) do |molde, contexto|
      contexto.partes.each { |peca| molde.molde_pecas.create!(peca: peca) }
    end
  end
end
