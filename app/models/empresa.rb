# The company this instance serves. One instance per empresa (docs/plano.md,
# Etapa 3.1), so there is at most one row and data tables carry no empresa_id.
class Empresa < ApplicationRecord
  include GeraUuid
  include PrecosDoDtf

  has_many :vinculos, dependent: :destroy
  # Etapa 2.3: the paper whose width gives an arte's meters per piece.
  belongs_to :papel_padrao, class_name: "MateriaPrima", optional: true
  # Etapa 2.3d1: the DTF film as a material, whose width replaces the typed one.
  belongs_to :filme_dtf_padrao, class_name: "MateriaPrima", optional: true

  validates :nome, presence: true
  # Etapa 2.2 (1/3): the paper's width and the baixa's warning band.
  validates :largura_papel_mm, numericality: { only_integer: true, greater_than: 0 }
  validates :tolerancia_abaixo_pct, numericality: { only_integer: true, in: 0..100 }
  validates :tolerancia_acima_pct, numericality: { only_integer: true, in: 0..1000 }
  # Etapa 2.4: the cost per pair's parts; blank until the dono sets them.
  validates :custo_impressao_metro, :custo_corte_peca, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  # Etapa 2.6a: the DTF film (a width, not a material), its edges, the
  # default space between etiquetas and the pedido's default extra rows.
  validates :largura_filme_dtf_mm, numericality: { only_integer: true, greater_than: 0 }
  validates :margem_filme_dtf_mm, :fileiras_extras_dtf, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  # Etapa 2.7b: the tecido's print per meter and minimum meters per item.
  validates :preco_impressao_metro_tecido, :metragem_minima_tecido, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :espacamento_dtf_mm, numericality: { greater_than_or_equal_to: 0, less_than: 1000 }
  validate :margens_cabem_no_filme
  # Etapa 2.6b1: every DTF size's fit follows the film.
  after_update_commit -> { EncaixeDaEtiqueta.atualizar_todas! }, if: -> { (saved_changes.keys & %w[largura_filme_dtf_mm filme_dtf_padrao_id margem_filme_dtf_mm espacamento_dtf_mm]).any? }
  validate :papel_padrao_e_papel
  validate :filme_dtf_padrao_e_filme
  validate :visibilidade_cliente_valida
  validate :unica_por_instancia, on: :create

  # Usage: Empresa.atual&.nome
  def self.atual
    first
  end

  # The paper width the artes are fitted on: the default paper's, else the
  # width typed while no paper is registered (Etapa 2.3).
  # Usage: Empresa.atual.largura_papel_efetiva_mm # => 1600
  def largura_papel_efetiva_mm
    papel_padrao&.largura_mm || largura_papel_mm
  end

  # The DTF film's width: the default film's, else the typed one while no
  # film is registered (Etapa 2.3d1, like the paper).
  # Usage: Empresa.atual.largura_filme_dtf_efetiva_mm # => 600
  def largura_filme_dtf_efetiva_mm
    filme_dtf_padrao&.largura_mm || largura_filme_dtf_mm
  end

  # The DTF film's width the etiquetas may take: the margin left at each edge
  # (Etapa 2.6a). Usage: Empresa.atual.largura_util_filme_dtf_mm # => 570
  def largura_util_filme_dtf_mm
    largura_filme_dtf_efetiva_mm - (2 * margem_filme_dtf_mm)
  end

  # Every etiqueta: the dono's price per meter is the one of those without a
  # client's own (PrecoDaEtiqueta skips them when their client has one).
  def etiquetas_do_preco
    Arquivo.where(arte: Arte.where(tipo: "dtf"))
  end

  # Both costs set: the cost per pair can be computed (Etapa 2.4).
  def custos_definidos?
    !custo_impressao_metro.nil? && !custo_corte_peca.nil?
  end

  private

  def papel_padrao_e_papel
    return if papel_padrao.nil? || papel_padrao.tipo == "papel"

    errors.add(:papel_padrao, "#{papel_padrao.nome_completo} is a #{papel_padrao.tipo}; expected a material of type papel")
  end

  def filme_dtf_padrao_e_filme
    return if filme_dtf_padrao.nil? || filme_dtf_padrao.tipo == "filme_dtf"

    errors.add(:filme_dtf_padrao, "#{filme_dtf_padrao.nome_completo} is a #{filme_dtf_padrao.tipo}; expected a material of type filme_dtf")
  end

  def margens_cabem_no_filme
    return unless largura_filme_dtf_mm.is_a?(Integer) && margem_filme_dtf_mm.is_a?(Integer)
    return if largura_util_filme_dtf_mm.positive?

    errors.add(:margem_filme_dtf_mm, "#{margem_filme_dtf_mm} mm at each edge leaves nothing of the #{largura_filme_dtf_efetiva_mm} mm film; expected less than half its width")
  end

  # Etapa 2.8 (3a): the default grid of what a cliente final sees.
  def visibilidade_cliente_valida
    TiposParaCliente.erros(visibilidade_cliente).each { |erro| errors.add(:visibilidade_cliente, erro) }
  end

  def unica_por_instancia
    return unless Empresa.exists?

    errors.add(:base, "this instance already has an empresa (\"#{Empresa.atual.nome}\"); expected at most one")
  end
end
