FactoryBot.define do
  factory :item_pedido_peca do
    item_pedido
    arquivo
    peca
    incluida { true }
    sequence(:position) { |n| n }
  end
end
