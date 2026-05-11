FactoryBot.define do
  factory :stamp do
    filename { "test_stamp" }
    extension { "tif" }
    mime_type { "image/tiff" }
    status { "pending" }
  end
end