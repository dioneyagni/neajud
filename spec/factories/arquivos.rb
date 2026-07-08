FactoryBot.define do
  factory :arquivo do
    filename { "test_arquivo" }
    extension { "tif" }
    mime_type { "image/tiff" }
    tipo_corte { "corte_estampa" }
    category { "artes" }

    trait :corte do
      category { "corte" }
      extension { "dxf" }
      mime_type { "image/vnd.dxf" }
      tipo_corte { nil }
    end
  end
end
