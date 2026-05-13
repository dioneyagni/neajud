FactoryBot.define do
  factory :stamp_version do
    stamp
    sequence(:version_number) { |n| n }
    uuid { SecureRandom.uuid }
    filename { stamp.filename }
    extension { stamp.extension }
    mime_type { stamp.mime_type }
    original_file { "original.#{extension}" }
    status { "pending" }
    approved { false }
    category { stamp.category }
  end
end
