# A job function (Admin, Designer, Produção…) whose grid of levels per área
# and special actions the dono edits (Etapa 0.5, 2/4). Many workers share
# one função. "Dono" is the system função: everything allowed, not editable,
# never deleted.
class Funcao < ApplicationRecord
  include GeraUuid
  include Excluivel

  class EmUso < StandardError; end

  # Created with the empresa (ConfiguracaoInicialService); the dono edits
  # them afterwards. Mirrors the table in docs/plano.md ("Usuários e
  # permissões"); 0 nenhum, 1 ver, 2 editar, 3 excluir.
  PADRAO = [
    { nome: "Dono", dono: true },
    { nome: "Admin", niveis: { pedidos: 3, clientes: 3, artes: 3, catalogo: 3, estoque: 3, lixeira: 0 }, acoes: %w[baixar_producao gerenciar_usuarios aprovar_arte] },
    { nome: "Atendimento", niveis: { pedidos: 3, clientes: 3, artes: 3, catalogo: 1, estoque: 2, lixeira: 0 }, acoes: %w[aprovar_arte] },
    { nome: "Designer", niveis: { pedidos: 1, clientes: 1, artes: 3, catalogo: 3, estoque: 0, lixeira: 0 }, acoes: %w[baixar_producao aprovar_arte] },
    { nome: "Produção", niveis: { pedidos: 1, clientes: 0, artes: 1, catalogo: 1, estoque: 1, lixeira: 0 }, acoes: %w[baixar_producao] }
  ].freeze

  has_many :vinculos, dependent: :restrict_with_error

  validates :nome, presence: true, uniqueness: { case_sensitive: false }
  validate :grade_valida
  validate :dono_imutavel, on: :update

  # Idempotent: an existing função of the same name is left as it is.
  # Usage: Funcao.criar_padrao!
  def self.criar_padrao!
    PADRAO.each { |atributos| find_or_create_by!(nome: atributos[:nome]) { |funcao| funcao.assign_attributes(atributos) } }
  end

  # Usage: Funcao.dono # => the system função
  def self.dono
    find_by!(dono: true)
  end

  # Refused for the dono função and while anyone active still has it.
  def excluir!(**autoria)
    raise EmUso, "the Dono função can't be deleted" if dono?
    raise EmUso, "\"#{nome}\" is used by #{vinculos.count} user(s); move them to another função first" if vinculos.exists?

    super
  end

  private

  def grade_valida
    Autorizacao.erros_da_grade(niveis, acoes).each { |erro| errors.add(:niveis, erro) }
  end

  def dono_imutavel
    return unless dono_was
    return unless will_save_change_to_niveis? || will_save_change_to_acoes? || will_save_change_to_dono? || will_save_change_to_nome?

    errors.add(:base, "the Dono função has every permission and can't be changed")
  end
end
