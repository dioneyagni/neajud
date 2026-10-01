FactoryBot.define do
  # A client's form; its name is assembled from the number, the modelo's
  # abbreviation and the suffix (Etapa 1.1, 4/5), e.g. "001-M1 MyString".
  factory :molde do
    sufixo { "MyString" }
    client
    modelo

    # The molde's own parts (Etapa 1.1, 3/5): create(:molde, partes: [lateral, lingua])
    transient do
      partes { [] }
    end

    after(:create) do |molde, contexto|
      contexto.partes.each { |peca| molde.molde_pecas.create!(peca: peca) }
    end
  end
end
