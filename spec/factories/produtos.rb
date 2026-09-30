FactoryBot.define do
  factory :produto do
    sequence(:nome) { |n| "Produto #{n}" }
    grade { (18..46).map(&:to_s) }
  end
end
