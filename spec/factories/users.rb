FactoryBot.define do
  factory :user do
    sequence(:nome) { |n| "Pessoa #{n}" }
    sequence(:email_address) { |n| "pessoa#{n}@example.com" }
    password { "senha-segura-123" }
  end

  factory :empresa do
    nome { "Empresa Teste" }
  end

  factory :funcao do
    sequence(:nome) { |n| "Função #{n}" }
    niveis { {} }
    acoes { [] }

    # Etapa 2.8 (2/5): for a cliente final's vínculo.
    trait :para_cliente do
      para_cliente { true }
    end

    # The system função; reused, since there is only one.
    factory :funcao_dono do
      nome { "Dono" }
      dono { true }
      initialize_with { Funcao.find_or_initialize_by(dono: true) }
    end
  end

  factory :vinculo do
    user
    empresa { Empresa.atual || association(:empresa) }
    funcao { client ? association(:funcao, :para_cliente, niveis: { "pedidos" => 1 }) : association(:funcao_dono) }
  end
end
