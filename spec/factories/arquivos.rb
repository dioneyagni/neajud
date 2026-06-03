FactoryBot.define do
  factory :arquivo do
    filename { "test_arquivo" }
    extension { "tif" }
    mime_type { "image/tiff" }
    tipo_corte { "corte_estampa" }
  end
end
