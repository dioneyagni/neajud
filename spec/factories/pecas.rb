FactoryBot.define do
  factory :peca do
    sequence(:nome) { |n| "Peca #{n}" }
  end
end
