FactoryBot.define do
  factory :stamp_time_log do
    stamp
    previous_seconds { 0 }
    new_seconds { 3600 }
  end
end
