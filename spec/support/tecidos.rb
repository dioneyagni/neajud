# Corridas, cores lisas and fabrics for the tecido pedido's specs (Etapa 2.7a).
# Usage: tecido = criar_tecido(largura: "1.60")
#        cor = criar_obra_de_tecido("cor_lisa", client: c, materia_prima: tecido)
#        cor.arquivos.first # => the file the card adds
module Tecidos
  def criar_tecido(largura: "1.60", grupo: "Oxford", cor: "Azul", tipo: "tecido")
    MateriaPrima.create_with(tipo: tipo).find_or_create_by!(grupo_material: GrupoMaterial.find_or_create_by!(nome: grupo), cor_material: CorMaterial.find_or_create_by!(nome: cor),
                                                         largura: largura, gramatura: "200g")
  end

  # no_catalogo nil keeps the kind's default (a cor lisa is born in it).
  def criar_obra_de_tecido(tipo, client: nil, no_catalogo: nil, materia_prima: nil, filename: "#{tipo}-x")
    arte = Arte.novo_do_tipo(tipo)
    arte.no_catalogo = no_catalogo unless no_catalogo.nil?
    arte.update!(materia_prima: materia_prima)
    create(:arquivo, category: "artes", arte: arte, client: client, filename: filename)
    arte.reload
  end
end

RSpec.configure { |config| config.include Tecidos }
