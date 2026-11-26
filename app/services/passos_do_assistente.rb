# The first-run wizard's steps, in order (Primeiros passos 2/6a). How many
# there are isn't fixed (Dione, 26/11/2026: "eu não sei quantos passos vão
# dar"): adding, taking out or reordering one is a line here, its view
# (assistente/_passo_<chave>) and its method in AplicarPassoDoAssistente; the
# progress bar and "faltam N de M" follow by themselves.
#
# Usage: PassosDoAssistente.seguinte("produz").chave # => "quem"
#        PassosDoAssistente.posicao("horario")        # => 3
class PassosDoAssistente
  class Desconhecido < StandardError; end

  Passo = Struct.new(:chave, :rotulo, :titulo, keyword_init: true)

  TODOS = [
    Passo.new(chave: "produz", rotulo: "O que produzem", titulo: "O que vocês produzem?"),
    Passo.new(chave: "quem", rotulo: "Quem trabalha", titulo: "Quem trabalha com você?"),
    Passo.new(chave: "horario", rotulo: "Horário", titulo: "Que horas a fábrica trabalha?"),
    Passo.new(chave: "maquinas", rotulo: "Máquinas", titulo: "Quais máquinas vocês têm?"),
    Passo.new(chave: "materiais", rotulo: "Materiais", titulo: "Vamos cadastrar os materiais de costume")
  ].freeze

  def self.todos = TODOS
  def self.primeiro = TODOS.first

  # Usage: PassosDoAssistente.passo("quem").rotulo # => "Quem trabalha"
  def self.passo(chave)
    TODOS.find { |passo| passo.chave == chave.to_s } ||
      raise(Desconhecido, "#{chave.inspect} is not a step of the wizard; expected one of #{TODOS.map(&:chave).join(", ")}")
  end

  # 1-based place.
  def self.posicao(chave) = TODOS.index(passo(chave)) + 1

  # nil after the last one.
  def self.seguinte(chave) = TODOS[posicao(chave)]

  # nil before the first one.
  def self.anterior(chave)
    indice = posicao(chave) - 2
    TODOS[indice] if indice >= 0
  end

  # The steps left from this one on, itself included.
  def self.faltam(chave) = TODOS.size - posicao(chave) + 1
end
