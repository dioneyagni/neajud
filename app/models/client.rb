class Client < ApplicationRecord
  include GeraUuid
  include Excluivel
  include PrecosDoDtf

  has_many :arquivos, dependent: :nullify
  has_many :moldes, dependent: :destroy
  has_many :movimento_estoques, dependent: :destroy
  has_many :pedidos, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :responsible, presence: true
  # Etapa 2.8 (3a): this client's exceptions to the empresa's grid.
  validate { TiposParaCliente.erros(visibilidade).each { |erro| errors.add(:visibilidade, erro) } }

  def rotulo_lixeira
    name
  end

  # Its etiquetas outside the catálogo: their unit price comes from its price per meter.
  def etiquetas_do_preco
    Arquivo.where(client: self, arte: Arte.where(tipo: "dtf", no_catalogo: false))
  end

  scope :search, ->(q) {
    return all if q.blank?
    pattern = "%#{q.to_s.gsub(/[%_]/, '\\\\\0')}%"
    where("name LIKE ? OR responsible LIKE ?", pattern, pattern)
  }
end
