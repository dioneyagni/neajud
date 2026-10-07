class MateriaPrima < ApplicationRecord
  include GeraUuid
  belongs_to :grupo_material
  belongs_to :cor_material
  has_many :movimento_estoques, dependent: :restrict_with_error
  has_many :itens_pedido, class_name: "ItemPedido", dependent: :nullify

  validates :largura, presence: true
  validates :gramatura, presence: true
  validates :largura, uniqueness: { scope: %i[grupo_material_id cor_material_id gramatura] }

  # Etapa 2.2 (1/3): a new roll width gets every size's meters per piece.
  after_create_commit :calcular_metros_por_peca

  # The widths in use, in mm, for the sizes' meters per piece.
  # Usage: MateriaPrima.larguras_mm # => [1250, 1600]
  def self.larguras_mm
    all.filter_map(&:largura_mm).uniq.sort
  end

  # The roll's width in mm, read from the typed text ("1.40 m", "1,40",
  # "140 cm", "1400 mm"); a number without unit below 10 is meters. nil when
  # it has no number.
  # Usage: MateriaPrima.new(largura: "1.25 m").largura_mm # => 1250
  def largura_mm
    numero, unidade = largura.to_s.match(/(\d+(?:[.,]\d+)?)\s*(mm|cm|m)?/i)&.captures
    return nil unless numero

    valor = numero.tr(",", ".").to_f
    fator = { "mm" => 1, "cm" => 10, "m" => 1000 }[unidade&.downcase] || (valor < 10 ? 1000 : 1)
    (valor * fator).round
  end

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

  private

  def calcular_metros_por_peca
    return unless largura_mm

    MetrosPorPecaJob.perform_later(Tamanho.joins(:arquivo).merge(Arquivo.ativos).ids, [ largura_mm ])
  end
end
