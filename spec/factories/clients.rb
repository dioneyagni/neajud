FactoryBot.define do
  factory :client do
    sequence(:name) { |n| "Client #{n}" }
    responsible { "Test Responsible" }
  end
end
