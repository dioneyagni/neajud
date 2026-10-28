# A material's group, acting as its family (Dublagem 1/5, decided 27/10/2026,
# after Akeneo's families of required attributes): its roles — a superfície
# goes on the face, a base dubs another, a group may be both (TNT) — whether
# it prints (sim; ressalvas, whose text the tecido pedido shows as a warning;
# não, never offered there) and which attributes its materials ask for, each
# required or not (largura always is). Never "tecido": a Telinha and a TNT
# both print, but only the TNT dubs another.
class GrupoMaterial < ApplicationRecord
  ESTAMPAVEL = %w[sim ressalvas nao].freeze
  ROTULOS_DO_ESTAMPAVEL = { "sim" => "Estampável", "ressalvas" => "Com ressalvas", "nao" => "Não estampa" }.freeze
  # The fixed list a group picks from (D5): what a material may have besides
  # its color and width.
  ATRIBUTOS = %w[gramatura densidade espessura_mm micras fornecedor].freeze
  ROTULOS_DOS_ATRIBUTOS = { "gramatura" => "Gramatura", "densidade" => "Densidade", "espessura_mm" => "Espessura (mm)",
                            "micras" => "Micras", "fornecedor" => "Fornecedor" }.freeze

  include GeraUuid
  has_many :materia_primas, dependent: :restrict_with_error

  validates :nome, presence: true, uniqueness: { case_sensitive: false }
  validates :estampavel, inclusion: { in: ESTAMPAVEL, message: "%{value} is not a printing option; expected one of #{ESTAMPAVEL.join(", ")}" }
  validates :ressalva, presence: { message: "diz qual é a ressalva (o aviso que o pedido mostra)" }, if: :com_ressalvas?
  validate :atributos_conhecidos

  scope :search, ->(q) {
    return all if q.blank?
    pattern = "%#{q.to_s.gsub(/[%_]/, '\\\\\0')}%"
    where("nome LIKE ?", pattern)
  }
  scope :estampaveis, -> { where.not(estampavel: "nao") }

  # Sets the attributes asked from the form's two lists; a required one is
  # asked too.
  # Usage: grupo.definir_atributos(pede: %w[densidade], obrigatorios: %w[espessura_mm])
  #        grupo.atributos # => { "densidade" => false, "espessura_mm" => true }
  def definir_atributos(pede:, obrigatorios:)
    escolhidos = ATRIBUTOS & (Array(pede) | Array(obrigatorios))
    self.atributos = escolhidos.index_with { |atributo| Array(obrigatorios).include?(atributo) }
  end

  # Usage: espuma.pede?("densidade") # => true
  def pede?(atributo) = atributos.key?(atributo.to_s)

  # Usage: espuma.exige?("densidade") # => true
  def exige?(atributo) = atributos[atributo.to_s] == true

  def com_ressalvas? = estampavel == "ressalvas"

  private

  def atributos_conhecidos
    desconhecidos = atributos.keys - ATRIBUTOS
    errors.add(:atributos, "#{desconhecidos.inspect} are not material attributes; expected some of #{ATRIBUTOS.join(", ")}") if desconhecidos.any?
  end
end
