# The company this instance serves. One instance per empresa (docs/plano.md,
# Etapa 3.1), so there is at most one row and data tables carry no empresa_id.
class Empresa < ApplicationRecord
  include GeraUuid

  has_many :vinculos, dependent: :destroy
  # Etapa 2.3: the paper whose width gives an arte's meters per piece.
  belongs_to :papel_padrao, class_name: "MateriaPrima", optional: true

  validates :nome, presence: true
  # Etapa 2.2 (1/3): the paper's width and the baixa's warning band.
  validates :largura_papel_mm, numericality: { only_integer: true, greater_than: 0 }
  validates :tolerancia_abaixo_pct, numericality: { only_integer: true, in: 0..100 }
  validates :tolerancia_acima_pct, numericality: { only_integer: true, in: 0..1000 }
  # Etapa 2.4: the cost per pair's parts; blank until the dono sets them.
  validates :custo_impressao_metro, :custo_corte_peca, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :papel_padrao_e_papel
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

  # Both costs set: the cost per pair can be computed (Etapa 2.4).
  def custos_definidos?
    !custo_impressao_metro.nil? && !custo_corte_peca.nil?
  end

  private

  def papel_padrao_e_papel
    return if papel_padrao.nil? || papel_padrao.tipo == "papel"

    errors.add(:papel_padrao, "#{papel_padrao.nome_completo} is a #{papel_padrao.tipo}; expected a material of type papel")
  end

  def unica_por_instancia
    return unless Empresa.exists?

    errors.add(:base, "this instance already has an empresa (\"#{Empresa.atual.nome}\"); expected at most one")
  end
end
