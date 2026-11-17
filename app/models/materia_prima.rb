# A material in stock, counted in linear meters (Etapa 2.3, decided
# 09/10/2026): a tecido, the transfer papel, the dublagem filme or (2.3d1)
# the filme_dtf the etiquetas print on, with its
# sale price per meter (preco_metro; an entry's valor is what it cost).
# Dublagem 1/5 (27/10/2026): its group says which attributes it asks for
# (GrupoMaterial#atributos) — gramatura, densidade, espessura, micras,
# fornecedor — and which are required; a requirement added later doesn't
# refuse the materials already there, it marks them (atributos_faltando).
# Dublagem 5b2a (12/11/2026, Q1a): the group may count it in kg instead (the
# cola): no width, its preco_metro then the price per kg.
class MateriaPrima < ApplicationRecord
  # The insumos say the stage that uses them up (decided 28/10/2026): the
  # papel and the filme DTF at Impressão, the kraft at Calandra, the plástico
  # de sucção on the cutting table. None is offered where a fabric is chosen.
  # Dublagem 3/5 (02/11/2026): a dublado is a Construcao's own material, made
  # and priced by it — never typed nor turned into another type by hand.
  TIPOS = %w[tecido papel filme filme_dtf kraft plastico_succao dublado].freeze
  ROTULOS_DOS_TIPOS = { "tecido" => "Tecido", "papel" => "Papel (impressão)", "filme" => "Ligante (dublagem)", "filme_dtf" => "Filme DTF (impressão)",
                        "kraft" => "Kraft (calandra)", "plastico_succao" => "Plástico de sucção (corte)", "dublado" => "Dublado" }.freeze

  include GeraUuid
  belongs_to :grupo_material
  belongs_to :cor_material
  has_many :movimento_estoques, dependent: :restrict_with_error
  has_many :itens_pedido, class_name: "ItemPedido", dependent: :nullify
  has_one :construcao, dependent: :restrict_with_error

  # A group that doesn't weigh its materials (Espuma) leaves gramatura blank;
  # the column is not null, as before 1/5.
  attribute :gramatura, default: ""
  normalizes :gramatura, with: ->(valor) { valor.to_s.strip }, apply_to_nil: true
  normalizes :densidade, :fornecedor, with: ->(valor) { valor.squish.presence }

  # Dublagem 5b2a: a material counted in kg (the cola) has no roll width.
  attribute :largura, default: ""
  normalizes :largura, with: ->(valor) { valor.to_s.strip }, apply_to_nil: true
  validates :largura, presence: true, unless: :em_kg?
  # A dublado is told apart by its construção, not by its group and color.
  validates :largura, uniqueness: { scope: %i[grupo_material_id cor_material_id gramatura densidade espessura_mm micras consumo_g_m2 fornecedor] }, unless: :dublado?
  validates :espessura_mm, numericality: { greater_than: 0 }, allow_nil: true
  validates :consumo_g_m2, numericality: { greater_than: 0 }, allow_nil: true
  validates :micras, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :atributos_obrigatorios, on: :create
  validate :dublado_continua_dublado, on: :update
  validate :em_kg_nao_e_tecido
  validates :tipo, inclusion: { in: TIPOS, message: "%{value} is not a material type; expected one of #{TIPOS.join(", ")}" }
  validates :preco_metro, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # What a fabric is chosen from: never a ligante or an insumo.
  scope :tecidos, -> { where(tipo: "tecido") }
  scope :papeis, -> { where(tipo: "papel") }
  scope :filmes_dtf, -> { where(tipo: "filme_dtf") }
  scope :ligantes, -> { where(tipo: "filme") }
  # What a tecido pedido prints on: a tecido whose group prints (sim or with
  # ressalvas), never one that doesn't (Dublagem 1/5).
  scope :estampaveis, -> { tecidos.where(grupo_material: GrupoMaterial.estampaveis) }

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
  # ("Espuma TC4 3 mm"), then color, width, gramatura, consumption and
  # fornecedor; a material without them keeps its pre-1/5 name.
  # Usage: espuma.nome_completo # => "Espuma TC4 3 mm-Branco-1.40 m"
  #        cola.nome_completo   # => "Cola PU-Branco-120 g/m²" (no width: kg, 5b2a)
  def nome_completo
    return construcao.nome if dublado? && construcao

    consumo = consumo_g_m2 && "#{numero_curto(consumo_g_m2)} g/m²"
    [ cabeca_do_nome, cor_material.nome, largura.presence, gramatura.presence, consumo, fornecedor ].compact.join("-")
  end

  # What its stock is counted in, its group's (Dublagem 5b2a): "m" or "kg".
  # Usage: cola.unidade # => "kg"
  def unidade = grupo_material&.unidade || "m"

  def em_kg? = unidade == "kg"

  # The group with its densidade, espessura and micras, then the color: a
  # construção's layer (Dublagem 3/5). Usage: espuma.nome_da_camada # => "Espuma TC4 3 mm Branco"
  def nome_da_camada
    "#{cabeca_do_nome} #{cor_material.nome}"
  end

  # The attributes its group requires that it lacks — a requirement added
  # after it was registered. Usage: espuma_antiga.atributos_faltando # => ["densidade"]
  def atributos_faltando
    return [] if grupo_material.nil? || dublado?

    grupo_material.atributos.select { |_atributo, obrigatorio| obrigatorio }.keys.select { |atributo| self[atributo].blank? }
  end

  def dublado? = tipo == "dublado"

  # Something already counts on it: a stock movement or a pedido item. A
  # construção in use keeps its layers (Dublagem 3/5, decision 5).
  def em_uso?
    movimento_estoques.exists? || itens_pedido.exists?
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

  def dublado_continua_dublado
    return unless will_save_change_to_tipo? && tipo_in_database.to_s.then { |antes| antes == "dublado" || dublado? }

    errors.add(:tipo, "#{tipo_in_database} can't become #{tipo}: a dublado is made by its construção only")
  end

  # A fabric is sold and dubbed by the meter: kg is for the cola (5b2a).
  def em_kg_nao_e_tecido
    errors.add(:tipo, "#{tipo} can't be counted in kg (group #{grupo_material.nome}); expected a ligante or an insumo") if em_kg? && %w[tecido dublado].include?(tipo)
  end

  def cabeca_do_nome
    [ grupo_material.nome, densidade, espessura_mm && "#{numero_curto(espessura_mm)} mm", micras && "#{micras} µm" ].compact.join(" ")
  end

  def numero_curto(numero)
    ActiveSupport::NumberHelper.number_to_rounded(numero, precision: 2, strip_insignificant_zeros: true, separator: ",")
  end

  def calcular_metros_por_peca
    return unless largura_mm

    MetrosPorPecaJob.perform_later(Tamanho.joins(:arquivo).merge(Arquivo.ativos).ids, [ largura_mm ])
  end
end
