FactoryBot.define do
  factory :arquivo_version do
    arquivo
    sequence(:version_number) { |n| n }
    uuid { SecureRandom.uuid }
    filename { arquivo.filename }
    extension { arquivo.extension }
    mime_type { arquivo.mime_type }
    original_file { "original.#{extension}" }
    status { "pending" }
    approved { false }
    category { arquivo.category }
  end
end
