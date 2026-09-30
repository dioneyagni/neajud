class Molde < ApplicationRecord
  include GeraUuid
  include Excluivel
  include ReferenciaAtiva

  belongs_to :client
  belongs_to :modelo, optional: true
  atribui_por_uuid :client, :modelo
  has_many :arquivos, dependent: :nullify
  has_many :arquivo_moldes, dependent: :destroy
  has_many :vinculated_arquivos, through: :arquivo_moldes, source: :arquivo
  has_many :molde_pecas, dependent: :destroy
  has_many :configured_pecas, through: :molde_pecas, source: :peca
  has_many :vinculo_logs_saida, class_name: "ArquivoVinculoLog", foreign_key: :from_molde_id, dependent: :nullify
  has_many :vinculo_logs_entrada, class_name: "ArquivoVinculoLog", foreign_key: :to_molde_id, dependent: :nullify

  recusa_excluido :client, :modelo
  validates :nome, presence: true
  validates :nome, uniqueness: { scope: :client_id, case_sensitive: false }
  validate :intervalo_da_grade

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

  private

  def intervalo_da_grade
    return if tamanho_inicial.blank? && tamanho_final.blank?

    grade_do_produto = modelo&.grade.to_a
    return errors.add(:tamanho_inicial, "needs a modelo whose produto has a grade; #{modelo&.nome.inspect} has none") if grade_do_produto.empty?
    return if modelo.produto.trecho_da_grade(tamanho_inicial, tamanho_final)

    errors.add(:tamanho_final, "#{tamanho_inicial.inspect}–#{tamanho_final.inspect} is not a stretch of #{grade_do_produto.first}–#{grade_do_produto.last} (both ends in the grade, first ≤ last)")
  end
end
