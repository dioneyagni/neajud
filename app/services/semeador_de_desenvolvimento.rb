require Rails.root.join("db/seeds/desenvolvimento").to_s

# Adds the development database's starting groups and materials
# (db/seeds/desenvolvimento.rb; decided 28/10/2026). Only adds: a group,
# color or material already there — found by name, or by the attributes that
# identify a material — is never changed, since the dev database holds real
# data. Refuses any environment but development.
#
# Usage: SemeadorDeDesenvolvimento.new.call
#        # => { criados: ["Lona", "Lona-Bege-1.40 m-300g", …], existentes: ["Oxford", …] }
class SemeadorDeDesenvolvimento
  class AmbienteErrado < StandardError; end

  def initialize(ambiente: Rails.env, grupos: DadosDeDesenvolvimento::GRUPOS, materiais: DadosDeDesenvolvimento::MATERIAIS)
    @ambiente = ambiente.to_s
    @grupos = grupos
    @materiais = materiais
  end

  def call
    raise AmbienteErrado, "dev:semear only runs in development; this is #{@ambiente.inspect}" unless @ambiente == "development"

    # Primeiros passos 2/6a: the adding is shared with the wizard's materials step.
    CadastroDeMateriais.new(grupos: @grupos, materiais: @materiais).call.slice(:criados, :existentes)
  end
end
