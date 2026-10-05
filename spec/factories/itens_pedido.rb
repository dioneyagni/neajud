FactoryBot.define do
  factory :item_pedido do
    pedido
    # A real arte in a pedido has a client: without one it can't be confirmed
    # (PedidoBloqueiosService :arte_sem_cliente, 01/10/2026).
    # Created even on build: the item's arte (Etapa 1.2, 3/3) comes from the
    # file's, which only exists once the file is saved.
    arquivo { association :arquivo, client: association(:client), strategy: :create }

    # A confirmable item: total quantity > 0 (see PedidoBloqueiosService).
    trait :com_quantidade do
      after(:create) { |item| item.grades.create!(tamanho_nome: "_total", quantidade: 1) }
    end
  end
end
