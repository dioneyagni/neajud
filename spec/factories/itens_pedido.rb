FactoryBot.define do
  factory :item_pedido do
    pedido
    # A real arte in a pedido has a client: without one it can't be confirmed
    # (PedidoBloqueiosService :arte_sem_cliente, 01/10/2026).
    arquivo { association :arquivo, client: association(:client) }

    # A confirmable item: total quantity > 0 (see PedidoBloqueiosService).
    trait :com_quantidade do
      after(:create) { |item| item.grades.create!(tamanho_nome: "_total", quantidade: 1) }
    end
  end
end
