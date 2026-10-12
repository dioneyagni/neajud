# Etapa 2.8 (4b, decided 12/10/2026): a cliente final uploads his artes, so the
# default "Cliente final" gets artes: editar; and a client's função or extras
# stop at Autorizacao::NIVEL_MAXIMO_PARA_CLIENTE (artes editar, the rest ver)
# — any above it is lowered to it, or it would no longer save.
class GiveClienteFinalArtesEditar < ActiveRecord::Migration[8.1]
  class Funcao < ActiveRecord::Base
    self.table_name = "funcoes"
  end

  class Vinculo < ActiveRecord::Base
    self.table_name = "vinculos"
  end

  NOME = "Cliente final".freeze
  MAXIMO = { "pedidos" => 1, "clientes" => 1, "artes" => 2, "catalogo" => 1, "estoque" => 1, "lixeira" => 0 }.freeze

  def up
    Funcao.where(para_cliente: true).find_each { |funcao| funcao.update!(niveis: limitar(funcao.niveis)) }
    Vinculo.where.not(client_id: nil).find_each do |vinculo|
      extras = vinculo.acessos_extras.to_h
      vinculo.update!(acessos_extras: extras.merge("niveis" => limitar(extras.fetch("niveis", {})))) if extras.key?("niveis")
    end
    funcao = Funcao.find_by(nome: NOME, para_cliente: true)
    funcao&.update!(niveis: funcao.niveis.to_h.merge("artes" => 2))
  end

  # Only the default's artes go back; a level lowered by `up` stays lowered
  # (it was beyond what a client may have).
  def down
    funcao = Funcao.find_by(nome: NOME, para_cliente: true)
    funcao&.update!(niveis: funcao.niveis.to_h.merge("artes" => 1))
  end

  private

  def limitar(niveis)
    niveis.to_h.to_h { |area, nivel| [ area, [ nivel.to_i, MAXIMO.fetch(area.to_s, 0) ].min ] }
  end
end
