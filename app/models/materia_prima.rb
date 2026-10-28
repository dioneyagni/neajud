# A material in stock, counted in linear meters (Etapa 2.3, decided
# 09/10/2026): a tecido, the transfer papel, the dublagem filme or (2.3d1)
# the filme_dtf the etiquetas print on, with its
# sale price per meter (preco_metro; an entry's valor is what it cost).
# Dublagem 1/5 (27/10/2026): its group says which attributes it asks for
# (GrupoMaterial#atributos) — gramatura, densidade, espessura, micras,
# fornecedor — and which are required; a requirement added later doesn't
# refuse the materials already there, it marks them (atributos_faltando).
class MateriaPrima < ApplicationRecord
  TIPOS = %w[tecido papel filme filme_dtf].freeze
  ROTULOS_DOS_TIPOS = { "tecido" => "Tecido", "papel" => "Papel", "filme" => "Ligante (dublagem)", "filme_dtf" => "Filme DTF" }.freeze

  include GeraUuid
  belongs_to :grupo_material
  belongs_to :cor_material
  has_many :movimento_estoques, dependent: :restrict_with_error
  has_many :itens_pedido, class_name: "ItemPedido", dependent: :nullify

  # A group that doesn't weigh its materials (Espuma) leaves gramatura blank;
  # the column is not null, as before 1/5.
  attribute :gramatura, default: ""
  normalizes :gramatura, with: ->(valor) { valor.to_s.strip }, apply_to_nil: true
  normalizes :densidade, :fornecedor, with: ->(valor) { valor.squish.presence }

  validates :largura, presence: true
  validates :largura, uniqueness: { scope: %i[grupo_material_id cor_material_id gramatura densidade espessura_mm micras fornecedor] }
  validates :espessura_mm, numericality: { greater_than: 0 }, allow_nil: true
  validates :micras, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :atributos_obrigatorios, on: :create
  validates :tipo, inclusion: { in: TIPOS, message: "%{value} is not a material type; expected one of #{TIPOS.join(", ")}" }
  validates :preco_metro, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :papeis, -> { where(tipo: "papel") }
  scope :filmes_dtf, -> { where(tipo: "filme_dtf") }
  # What a tecido pedido prints on: a tecido whose group prints (sim or with
  # ressalvas), never one that doesn't (Dublagem 1/5).
  scope :estampaveis, -> { where(tipo: "tecido").where(grupo_material: GrupoMaterial.estampaveis) }

  # Etapa 2.2 (1/3): a new roll width gets every size's meters per piece.
  after_create_commit :calcular_metros_por_peca

  # The form's names for the group's attributes ("Espessura (mm)").
  def self.human_attribute_name(atributo, opcoes = {})
    GrupoMaterial::ROTULOS_DOS_ATRIBUTOS[atributo.to_s] || super
  end

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

  # The group with its densidade, espessura and micras when it has them
  # ("Espuma TC4 3 mm"), then color, width, gramatura and fornecedor; a
  # material without them keeps its pre-1/5 name.
  # Usage: espuma.nome_completo # => "Espuma TC4 3 mm-Branco-1.40 m"
  def nome_completo
    cabeca = [ grupo_material.nome, densidade, espessura_mm && "#{numero_curto(espessura_mm)} mm", micras && "#{micras} µm" ]
    [ cabeca.compact.join(" "), cor_material.nome, largura, gramatura.presence, fornecedor ].compact.join("-")
  end

  # The attributes its group requires that it lacks — a requirement added
  # after it was registered. Usage: espuma_antiga.atributos_faltando # => ["densidade"]
  def atributos_faltando
    return [] unless grupo_material

    grupo_material.atributos.select { |_atributo, obrigatorio| obrigatorio }.keys.select { |atributo| self[atributo].blank? }
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

  def atributos_obrigatorios
    atributos_faltando.each do |atributo|
      errors.add(atributo, "é obrigatório no grupo #{grupo_material.nome}")
    end
  end

  def numero_curto(numero)
    ActiveSupport::NumberHelper.number_to_rounded(numero, precision: 2, strip_insignificant_zeros: true, separator: ",")
  end

  def calcular_metros_por_peca
    return unless largura_mm

    MetrosPorPecaJob.perform_later(Tamanho.joins(:arquivo).merge(Arquivo.ativos).ids, [ largura_mm ])
  end
end
