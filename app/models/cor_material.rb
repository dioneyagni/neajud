class CorMaterial < ApplicationRecord
  COLOR_HEX = {
    "Branco" => "#FFFFFF",
    "Bege" => "#F5F5DC",
    "Rosa" => "#FFC0CB",
    "Amarelo" => "#FFFF00",
    "Cinza" => "#808080",
    "Verde" => "#008000",
    "Azul" => "#0000FF",
    "Laranja" => "#FFA500",
    "Roxo" => "#800080",
    "Vermelho" => "#FF0000",
    "Marrom" => "#A52A2A",
    "Preto" => "#000000"
  }.freeze

  has_many :materia_primas, dependent: :restrict_with_error

  validates :nome, presence: true, uniqueness: { case_sensitive: false }
end
