FactoryBot.define do
  factory :tamanho do
    stamp
    sequence(:nome) { |n| "Size #{n}" }
    position { 1 }
    width_mm { 100.0 }
    height_mm { 50.0 }
    area_mm2 { 5000.0 }
  end
end
