FactoryBot.define do
  factory :arquivo_time_log do
    arquivo
    previous_seconds { 0 }
    new_seconds { 3600 }
  end
end
