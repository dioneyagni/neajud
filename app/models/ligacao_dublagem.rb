# One ligação of the dublagem network (Dublagem 2/5, decided 29/10/2026; in
# the database since rede editável 1/2, 09/11/2026, Q1a): two groups that
# dub — the upper one first, whose lado it may name —, before or after the
# estampa, with the usual ligantes and a situação's in their place. The pair
# holds in either order (decision 2), so it is never repeated in any order
# with the same lado among the ones not in the trash. Since rede editável
# 2/2a (10/11/2026) the team edits it on its own page, goes to the trash
# (Q5a) and keeps a histórico of every save (Q3a, AlteracaoDaRede).
class LigacaoDublagem < ApplicationRecord
  self.table_name = "ligacoes_dublagem"

  include GeraUuid
  include Excluivel
  belongs_to :grupo_a, class_name: "GrupoMaterial"
  belongs_to :grupo_b, class_name: "GrupoMaterial"
  has_many :ligantes, -> { order(:posicao) }, class_name: "LiganteDaLigacao", inverse_of: :ligacao_dublagem, dependent: :destroy, autosave: true
  has_many :alteracoes, -> { recentes }, class_name: "AlteracaoDaRede", as: :registro, dependent: :destroy

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
    usuais, de_situacao = ligantes_mantidos.partition { |ligante| ligante.situacao_dublagem.nil? }
    RedeDeDublagens::Ligacao.new(uuid: uuid, par: [ grupo_a.nome, grupo_b.nome ], grupos: [ grupo_a, grupo_b ], lado: lado, dubla: dubla, a_confirmar: a_confirmar,
                                 ligantes: usuais.map(&:para_rede),
                                 situacoes: de_situacao.group_by { |ligante| ligante.situacao_dublagem.chave }.transform_values { |lista| lista.map(&:para_rede) })
  end

  # Usage: ligacao.nome # => "Oxford com Espuma", "Oxford com Lona (lado trama)"
  def nome = "#{grupo_a.nome} com #{grupo_b.nome}#{" (lado #{lado})" if lado}"

  def rotulo_lixeira = nome

  # What the histórico compares (MudancasDaLigacao), as the page reads it.
  # Usage: ligacao.resumo # => { "lado" => "qualquer", "dubla" => "antes", "ligantes" => ["Filme 25 µm"], "situacoes" => { "Tecido molha" => ["Filme PU"] }, "a_confirmar" => ["ligantes"] }
  def resumo
    rede = para_rede
    situacoes = SituacaoDublagem.where(chave: rede.situacoes.keys).to_h { |situacao| [ situacao.chave, situacao.nome ] }
    { "lado" => lado || "qualquer", "dubla" => dubla, "ligantes" => rede.ligantes.map(&:descricao),
      "situacoes" => rede.situacoes.to_h { |chave, lista| [ situacoes.fetch(chave, chave), lista.map(&:descricao) ] },
      "a_confirmar" => RedeDeDublagens::ROTULOS_A_CONFIRMAR.values_at(*a_confirmar) }
  end

  # Each a line of the histórico, and the network read again (update_columns
  # runs no after_commit). Restoring is refused while another ligação of the
  # same pair and lado is active (par_unico).
  def excluir!(**autoria)
    super
    registrar_na_rede!("mandou para a lixeira", autoria[:user])
  end

  def restaurar!(**autoria)
    self.deleted_at = nil
    raise ActiveRecord::RecordInvalid, self unless valid?

    super
    registrar_na_rede!("restaurou", autoria[:user])
  end

  private

  def ligantes_mantidos = ligantes.reject(&:marked_for_destruction?)

  def registrar_na_rede!(texto, user)
    alteracoes.create!(texto: texto, user: user)
    RedeDeDublagens.esquecer
  end

  def a_confirmar_conhecido
    desconhecidos = Array(a_confirmar) - RedeDeDublagens::A_CONFIRMAR
    errors.add(:a_confirmar, "#{desconhecidos.inspect} are not fields to confirm; expected some of #{RedeDeDublagens::A_CONFIRMAR.join(", ")}") if desconhecidos.any?
  end

  def par_unico
    return if excluido? || grupo_a.nil? || grupo_b.nil?
    return unless LigacaoDublagem.ativos.do_par(grupo_a, grupo_b).where(lado: lado).where.not(id: id).exists?

    errors.add(:base, "#{nome} já está na rede; cada par entra uma vez com o mesmo lado, em qualquer ordem")
  end
end
