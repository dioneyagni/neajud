class CutLayer < ApplicationRecord
  belongs_to :arquivo_version, foreign_key: :arquivo_version_id
end
