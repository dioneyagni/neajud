# What the first-run wizard offers (Primeiros passos 2/6a): config/assistente.yml
# read once — the kinds of work with their machine trabalhos and typical
# materials, what each default função does, the turnos proposed, the
# materials and their groups. A kind naming a trabalho or a material that
# doesn't exist raises, naming it.
#
# Usage: ConteudoDoAssistente.tipos.keys # => ["calcado", "dtf", "corrida", "cor_lisa", "dublagem"]
#        ConteudoDoAssistente.materiais_de(%w[dtf]).keys # => ["filme_dtf"]
class ConteudoDoAssistente
  class Invalido < StandardError; end

  ARQUIVO = Rails.root.join("config/assistente.yml")

  Tipo = Struct.new(:chave, :nome, :descricao, :trabalhos, :materiais, keyword_init: true)

  class << self
    def tipos
      @tipos ||= dados.fetch("tipos").to_h { |chave, t| [ chave, Tipo.new(chave: chave, **t.symbolize_keys) ] }.tap { |todos| validar(todos) }
    end

    def funcoes = dados.fetch("funcoes")
    def turnos = dados.fetch("turnos").map(&:symbolize_keys)

    # Every material, by its key: { grupo:, cor:, largura:, …, padrao: } as the stock saves it.
    def materiais
      @materiais ||= dados.fetch("materiais").transform_values { |m| m.symbolize_keys.transform_values { |v| v.is_a?(String) || v.is_a?(Integer) ? v : v.to_s } }
    end

    # The groups' rules, as GrupoMaterial takes them (also the dev seeds').
    def grupos
      @grupos ||= dados.fetch("grupos").map { |g| g.symbolize_keys.tap { |grupo| grupo[:pede] = Array(grupo[:pede]); grupo[:obrigatorios] = Array(grupo[:obrigatorios]) } }
    end

    # The typical materials of the kinds marked, in order, each once.
    # Usage: ConteudoDoAssistente.materiais_de(%w[calcado dtf]) # => { "papel" => {…}, …, "filme_dtf" => {…} }
    def materiais_de(chaves)
      chaves.flat_map { |chave| tipos.fetch(chave).materiais }.uniq.index_with { |id| materiais.fetch(id) }
    end

    # The machine trabalhos of the kinds marked (all, when none was answered).
    def trabalhos_de(chaves)
      return TrabalhosDeMaquina.chaves if chaves.nil?

      chaves.flat_map { |chave| tipos.fetch(chave).trabalhos }.uniq
    end

    private

    def dados
      @dados ||= YAML.safe_load_file(ARQUIVO)
    end

    def validar(todos)
      erros = todos.values.flat_map do |tipo|
        (tipo.trabalhos - TrabalhosDeMaquina.chaves).map { |t| "#{tipo.chave}: trabalho #{t.inspect} is not one of #{TrabalhosDeMaquina.chaves.join(", ")}" } +
          (tipo.materiais - materiais.keys).map { |m| "#{tipo.chave}: material #{m.inspect} is not in materiais" }
      end
      raise Invalido, "config/assistente.yml: #{erros.join("; ")}" if erros.any?
    end
  end
end
