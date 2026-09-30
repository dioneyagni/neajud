FactoryBot.define do
  factory :modelo do
    sequence(:nome) { |n| "Modelo #{n}" }
  end
end
