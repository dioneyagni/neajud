# A client's form (Etapa 1.1): code `NNN-ABR` + free suffix ("002-TNS
# Furado"). The number counts the client's moldes of every category and is
# never reused (trashed ones included); the abbreviation follows the modelo,
# so moving 002-TNS to Jogging makes it 002-JGG. `nome` stores the assembled
# name for search and sorting. The client is fixed once created.
#
# A variation (variacao_de, of the same or another client's molde) is born
# with the base's modelo, grade, parts and corte links copied — the real
# inheritance, following the base's changes, is Fase 5.
#
# Usage: Molde.create!(client: mks, modelo: tenis, sufixo: "Furado", variacao_de: base)
#          .nome # => "002-TNS Furado"
class Molde < ApplicationRecord
  include GeraUuid
  include Excluivel
  include ReferenciaAtiva
  include EscolheDonoDoTecido

  belongs_to :client
  belongs_to :modelo, optional: true
  belongs_to :variacao_de, class_name: "Molde", optional: true
  # Version lineage for Fase 5 (catalog versioning); not used yet.
  belongs_to :base, class_name: "Molde", optional: true
  has_many :variacoes, class_name: "Molde", foreign_key: :variacao_de_id, dependent: :nullify
  has_many :referencias, -> { order(:nome) }, dependent: :destroy
  atribui_por_uuid :client, :modelo, :variacao_de
  has_many :arquivos, dependent: :nullify
  has_many :arquivo_moldes, dependent: :destroy
  has_many :vinculated_arquivos, through: :arquivo_moldes, source: :arquivo
  has_many :molde_pecas, dependent: :destroy
  # Price per pair by band of the grade (Etapa 2.4).
  has_many :faixas_de_preco, -> { order(:id) }, class_name: "FaixaDePreco", dependent: :destroy
  has_many :configured_pecas, through: :molde_pecas, source: :peca
  has_many :vinculo_logs_saida, class_name: "ArquivoVinculoLog", foreign_key: :from_molde_id, dependent: :nullify
  has_many :vinculo_logs_entrada, class_name: "ArquivoVinculoLog", foreign_key: :to_molde_id, dependent: :nullify

  recusa_excluido :client, :modelo, :variacao_de
  before_validation :herdar_modelo_e_grade_da_base, on: :create
  before_validation :atribuir_numero, on: :create
  before_validation :montar_nome
  validates :modelo, presence: { message: "is required: the code needs its abbreviation (choose a modelo or a base molde)" }, on: :create
  validates :numero, presence: true, uniqueness: { scope: :client_id }
  validate :intervalo_da_grade
  validate :cliente_e_base_fixos, on: :update
  after_create :copiar_partes_e_cortes_da_base, if: :variacao_de

  scope :search, ->(q) {
    return all if q.blank?
    pattern = "%#{q.to_s.gsub(/[%_]/, '\\\\\0')}%"
    where("nome LIKE ?", pattern)
  }

  scope :for_client, ->(client_id) {
    where(client_id: client_id)
  }

  # The stretch of its produto's grade this molde uses (Etapa 1.1, 3/5), e.g.
  # 24 to 34 of Calçado's 18–46; empty when not chosen or the produto has
  # no grade (Banner).
  # Usage: molde.grade # => ["24", "25", …, "34"]
  def grade
    return [] if tamanho_inicial.blank?

    modelo&.produto&.trecho_da_grade(tamanho_inicial, tamanho_final) || []
  end

  # After the modelo's abbreviation changed in the official list
  # (CatalogoOficial): the stored name follows, without touching validations
  # a legacy row may fail.
  # Usage: modelo.moldes.each(&:atualizar_nome!)
  def atualizar_nome!
    montar_nome
    update_column(:nome, nome) if nome_changed?
  end

  # The price per pair of a number (Etapa 2.4); nil when no band covers it.
  # Usage: molde.preco_do_par("27") # => 9.5
  def preco_do_par(numero)
    faixas_de_preco.find { |faixa| faixa.numeros.include?(numero.to_s) }&.preco_par
  end

  # "002-TNS"; without abbreviation (a trashed dev sample's modelo) "002".
  def codigo
    [ format("%03d", numero.to_i), modelo&.abreviacao ].compact.join("-")
  end

  private

  def herdar_modelo_e_grade_da_base
    return unless variacao_de && modelo.nil?

    self.modelo = variacao_de.modelo
    self.tamanho_inicial ||= variacao_de.tamanho_inicial
    self.tamanho_final ||= variacao_de.tamanho_final
  end

  # Counts the trashed ones too: a number is never reused.
  def atribuir_numero
    return if numero.present? || client_id.nil?

    self.numero = Molde.where(client_id: client_id).maximum(:numero).to_i + 1
  end

  def montar_nome
    self.nome = [ codigo, sufixo.presence ].compact.join(" ")
  end

  # The number belongs to the client's sequence, and the copy from the base
  # happens once, at creation.
  def cliente_e_base_fixos
    errors.add(:client, "can't change (#{client_id_was} → #{client_id}): the code #{codigo} is in that client's sequence") if client_id_changed?
    errors.add(:variacao_de, "can't change after creation (was #{variacao_de_id_was.inspect})") if variacao_de_id_changed?
  end

  # Trashed peças and cortes are left out: they can't be linked anew.
  def copiar_partes_e_cortes_da_base
    variacao_de.molde_pecas.includes(:peca).reject { |p| p.peca.excluido? }.each do |parte|
      molde_pecas.create!(peca: parte.peca, needs_cut: parte.needs_cut, pecas_por_par: parte.pecas_por_par, espelhada: parte.espelhada)
    end
    variacao_de.arquivo_moldes.includes(:arquivo).reject { |l| l.arquivo.excluido? }.each do |ligacao|
      arquivo_moldes.create!(arquivo: ligacao.arquivo)
    end
  end

  def intervalo_da_grade
    return if tamanho_inicial.blank? && tamanho_final.blank?

    grade_do_produto = modelo&.grade.to_a
    return errors.add(:tamanho_inicial, "needs a modelo whose produto has a grade; #{modelo&.nome.inspect} has none") if grade_do_produto.empty?
    return if modelo.produto.trecho_da_grade(tamanho_inicial, tamanho_final)

    errors.add(:tamanho_final, "#{tamanho_inicial.inspect}–#{tamanho_final.inspect} is not a stretch of #{grade_do_produto.first}–#{grade_do_produto.last} (both ends in the grade, first ≤ last)")
  end
end
