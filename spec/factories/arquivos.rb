FactoryBot.define do
  factory :arquivo do
    filename { "test_arquivo" }
    extension { "tif" }
    mime_type { "image/tiff" }
  end
end
