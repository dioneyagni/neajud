FactoryBot.define do
  factory :item_pedido do
    pedido
    arquivo

    # A confirmable item: total quantity > 0 (see PedidoBloqueiosService).
    trait :com_quantidade do
      after(:create) { |item| item.grades.create!(tamanho_nome: "_total", quantidade: 1) }
    end
  end
end
