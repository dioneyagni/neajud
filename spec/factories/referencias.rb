FactoryBot.define do
  factory :referencia do
    molde
    sequence(:nome) { |n| (n + 18).to_s }
  end
end
