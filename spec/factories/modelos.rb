FactoryBot.define do
  # An official category (Etapa 1.1, 3/5); the real ones come from
  # config/catalogo_oficial.yml.
  factory :modelo do
    produto
    sequence(:nome) { |n| "Modelo #{n}" }
    sequence(:abreviacao) { |n| "M#{n}" }
  end
end
