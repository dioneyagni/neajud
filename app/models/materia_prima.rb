class MateriaPrima < ApplicationRecord
  belongs_to :grupo_material
  belongs_to :cor_material
  has_many :movimento_estoques, dependent: :restrict_with_error
  has_many :itens_pedido, class_name: "ItemPedido", dependent: :nullify

  validates :largura, presence: true
  validates :gramatura, presence: true
  validates :largura, uniqueness: { scope: %i[grupo_material_id cor_material_id gramatura] }

  def nome_completo
    "#{grupo_material.nome}-#{cor_material.nome}-#{largura}-#{gramatura}"
  end

  def saldo(cache = nil)
    if cache
      cache[id] || 0.0
    else
      entradas = movimento_estoques.where(tipo: "entrada").sum(:quantidade)
      saidas = movimento_estoques.where(tipo: "saida").sum(:quantidade)
      entradas - saidas
    end
  end
end
