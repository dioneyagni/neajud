FactoryBot.define do
  # A client's form; its name is assembled from the number, the modelo's
  # abbreviation and the suffix (Etapa 1.1, 4/5), e.g. "001-M1 MyString".
  factory :molde do
    sufixo { "MyString" }
    client
    modelo

    # The molde's own parts (Etapa 1.1, 3/5): create(:molde, partes: [lateral, lingua])
    # Etapa 2.4: create(:molde, preco: 10) prices every number of the produto's grade.
    transient do
      partes { [] }
      preco { nil }
    end

    after(:create) do |molde, contexto|
      contexto.partes.each { |peca| molde.molde_pecas.create!(peca: peca) }
      next unless contexto.preco

      grade = molde.modelo.produto.grade
      molde.faixas_de_preco.create!(tamanho_inicial: grade.first, tamanho_final: grade.last, preco_par: contexto.preco)
    end
  end
end
