FactoryBot.define do
  factory :ban do
    ip_address { "192.168.1.1" }
    reason { "Abuse detected" }
  end
end