FactoryBot.define do
  factory :user do
    sequence(:nome) { |n| "Pessoa #{n}" }
    sequence(:email_address) { |n| "pessoa#{n}@example.com" }
    password { "senha-segura-123" }
  end

  factory :empresa do
    nome { "Empresa Teste" }
  end

  factory :vinculo do
    user
    empresa { Empresa.atual || association(:empresa) }
    perfis { %w[dono] }
  end
end
