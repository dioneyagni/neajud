%w[Oxford Nylon Poliéster Algodão Elastano Linho Acrílico Viscose].each do |nome|
  GrupoMaterial.find_or_create_by!(nome: nome)
end

%w[Branco Preto Vermelho Azul Verde Amarelo Cinza Bege Marrom Rosa Lilax].each do |nome|
  CorMaterial.find_or_create_by!(nome: nome)
end

[
  { name: "Fagner", responsible: "Fagner" },
  { name: "Lipe", responsible: "Lipe" }
].each do |attrs|
  Client.find_or_create_by!(name: attrs[:name]) do |c|
    c.responsible = attrs[:responsible]
  end
end
