# A situação a construção may be in (plano Etapa 2.9 D6; in the database
# since rede editável 1/2, 09/11/2026, Q1a): it changes the ligantes of the
# ligações that list it. Construcao#situacao keeps its chave.
#
# Since rede editável 2/2b (10/11/2026) the team adds and renames them from
# the rede's page. The chave comes from the first name and never changes, so
# a rename never loses a construção's situação; there is no trash on purpose
# (a situação no ligação lists changes nothing).
#
# Usage: SituacaoDublagem.create!(nome: "Tecido úmido").chave # => "tecido_umido"
class SituacaoDublagem < ApplicationRecord
  self.table_name = "situacoes_dublagem"

  include GeraUuid
  has_many :ligantes, class_name: "LiganteDaLigacao", inverse_of: :situacao_dublagem, dependent: :restrict_with_error
  has_many :alteracoes, -> { recentes }, class_name: "AlteracaoDaRede", as: :registro, dependent: :restrict_with_error

  normalizes :nome, with: ->(nome) { nome.squish }

  before_validation :gerar_chave, on: :create
  validates :chave, presence: true, uniqueness: true, format: { with: /\A[a-z0-9_]+\z/, message: "%{value} is not a key; expected lowercase letters, digits and _" }
  validates :nome, presence: true, uniqueness: { case_sensitive: false, message: "%{value} já é uma situação da rede" }

  after_commit { RedeDeDublagens.esquecer }

  # The chave for a name: its words without accents, joined by _, with _2,
  # _3… when taken. Usage: SituacaoDublagem.chave_para("Vai frequência") # => "vai_frequencia"
  def self.chave_para(nome)
    base = I18n.transliterate(nome.to_s).parameterize(separator: "_").presence || "situacao"
    (1..).lazy.map { |numero| numero == 1 ? base : "#{base}_#{numero}" }.find { |chave| !exists?(chave: chave) }
  end

  private

  def gerar_chave
    self.chave = self.class.chave_para(nome) if chave.blank? && nome.present?
  end
end
