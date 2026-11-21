# A machine of the factory (Máquinas 1/5, decided 20/11/2026): a name and
# what it does — one or more trabalhos of TrabalhosDeMaquina, each at its
# speed (Q7: one machine may do several, the Calandra 2 calandra and dubla).
# The stages a trabalho serves take the sum of its active machines as their
# informado (RitmoProducao#informado). Trashed, not deleted; its name stays
# unique across the trash. Saved or trashed, the Painel refreshes itself.
#
# Usage: maquina = Maquina.new(nome: "Calandra 2")
#        maquina.trabalhos.build(trabalho: "calandra", por_hora: 40)
#        maquina.save!
class Maquina < ApplicationRecord
  include GeraUuid
  include AvisaAFila
  include Excluivel

  # validate: false — the machine says which trabalho is wrong (trabalhos_validos).
  has_many :trabalhos, -> { order(:id) }, class_name: "TrabalhoDaMaquina", inverse_of: :maquina, autosave: true, validate: false, dependent: :destroy
  has_many :alteracoes, class_name: "AlteracaoDaMaquina", inverse_of: :maquina, dependent: :destroy

  validates :nome, presence: { message: "diga o nome da máquina" }
  validate :nome_unico
  validate :algum_trabalho
  validate :trabalhos_validos

  # The ones kept (an unchecked trabalho is marked for destruction until saved).
  def trabalhos_mantidos
    trabalhos.reject(&:marked_for_destruction?)
  end

  # Usage: maquina.trabalho_de("calandra") # => TrabalhoDaMaquina or nil
  def trabalho_de(chave)
    trabalhos_mantidos.find { |trabalho| trabalho.trabalho == chave.to_s }
  end

  # The histórico says it too, like a ligação's.
  def excluir!(**autoria)
    super
    alteracoes.create!(texto: "mandou para a lixeira", user: autoria[:user])
  end

  def restaurar!(**autoria)
    super
    alteracoes.create!(texto: "restaurou", user: autoria[:user])
  end

  def aviso_na_lixeira
    "A máquina \"#{nome}\" está na lixeira (desde #{deleted_at.strftime('%d/%m/%Y')}): restaure-a na Lixeira em vez de cadastrar de novo."
  end

  private

  # Case and spaces don't make another machine; one in the trash says so.
  def nome_unico
    return if nome.blank?

    igual = Maquina.where.not(id: id).find { |outra| outra.nome.strip.casecmp?(nome.strip) }
    return unless igual

    errors.add(:base, igual.excluido? ? igual.aviso_na_lixeira : "Já existe a máquina \"#{igual.nome}\": escolha outro nome.")
  end

  def algum_trabalho
    errors.add(:base, "Marque pelo menos um trabalho que a máquina faz.") if trabalhos_mantidos.empty?
  end

  def trabalhos_validos
    trabalhos_mantidos.reject(&:valid?).each do |trabalho|
      errors.add(:base, "#{trabalho.tipo_de_trabalho.nome}: #{trabalho.errors.full_messages.to_sentence}")
    end
  end
end
