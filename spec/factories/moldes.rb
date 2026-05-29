FactoryBot.define do
  factory :molde do
    sequence(:nome) { |n| "Molde #{n}" }
  end
end
