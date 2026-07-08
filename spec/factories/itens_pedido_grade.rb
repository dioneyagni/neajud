FactoryBot.define do
  factory :item_pedido_grade do
    item_pedido
    sequence(:tamanho_nome) { |n| "Tam #{n}" }
    quantidade { 1 }
  end
end
