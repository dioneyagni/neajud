FactoryBot.define do
  factory :stamp do
    filename { "test_stamp" }
    extension { "tif" }
    mime_type { "image/tiff" }
  end
end
