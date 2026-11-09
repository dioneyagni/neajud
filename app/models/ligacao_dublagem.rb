# One ligação of the dublagem network (Dublagem 2/5, decided 29/10/2026; in
# the database since rede editável 1/2, 09/11/2026, Q1a): two groups that
# dub — the upper one first, whose lado it may name —, before or after the
# estampa, with the usual ligantes and a situação's in their place. The pair
# holds in either order (decision 2), so it is never repeated in any order
# with the same lado.
class LigacaoDublagem < ApplicationRecord
  self.table_name = "ligacoes_dublagem"

  include GeraUuid
  belongs_to :grupo_a, class_name: "GrupoMaterial"
  belongs_to :grupo_b, class_name: "GrupoMaterial"
  has_many :ligantes, -> { order(:posicao) }, class_name: "LiganteDaLigacao", inverse_of: :ligacao_dublagem, dependent: :destroy

  # The ligações of a pair in either order (any lado).
  # Usage: LigacaoDublagem.do_par(oxford, lona).find_by(lado: nil)
  scope :do_par, ->(grupo_a, grupo_b) { where(grupo_a: grupo_a, grupo_b: grupo_b).or(where(grupo_a: grupo_b, grupo_b: grupo_a)) }

  validates :lado, inclusion: { in: RedeDeDublagens::LADOS, message: "%{value} is not a side; expected #{RedeDeDublagens::LADOS.join(" or ")}" }, allow_nil: true
  validates :dubla, inclusion: { in: RedeDeDublagens::DUBLA, message: "%{value} is not a momento; expected #{RedeDeDublagens::DUBLA.join(" or ")}" }
  validate :a_confirmar_conhecido
  validate :par_unico

  after_commit { RedeDeDublagens.esquecer }

  # The network's reading of it (RedeDeDublagens::Ligacao), by group names.
  def para_rede
    usuais, de_situacao = ligantes.partition { |ligante| ligante.situacao_dublagem.nil? }
    RedeDeDublagens::Ligacao.new(par: [ grupo_a.nome, grupo_b.nome ], grupos: [ grupo_a, grupo_b ], lado: lado, dubla: dubla, a_confirmar: a_confirmar,
                                 ligantes: usuais.map(&:para_rede),
                                 situacoes: de_situacao.group_by { |ligante| ligante.situacao_dublagem.chave }.transform_values { |lista| lista.map(&:para_rede) })
  end

  private

  def a_confirmar_conhecido
    desconhecidos = Array(a_confirmar) - RedeDeDublagens::A_CONFIRMAR
    errors.add(:a_confirmar, "#{desconhecidos.inspect} are not fields to confirm; expected some of #{RedeDeDublagens::A_CONFIRMAR.join(", ")}") if desconhecidos.any?
  end

  def par_unico
    return unless grupo_a && grupo_b && LigacaoDublagem.do_par(grupo_a, grupo_b).where(lado: lado).where.not(id: id).exists?

    errors.add(:base, "#{grupo_a.nome}–#{grupo_b.nome}#{" (#{lado})" if lado} is already in the network; expected once in any order")
  end
end
