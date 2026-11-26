# How the first-run wizard says things (Primeiros passos 2/6a).
module AssistenteHelper
  # A typical material as the step lists it (config/assistente.yml).
  # Usage: rotulo_do_material_tipico(grupo: "Papel", cor: "Branco", gramatura: "90g", largura: "1.60 m") # => "Papel · Branco · 90g · 1,60 m"
  def rotulo_do_material_tipico(dados)
    medida = dados[:gramatura] || (dados[:micras] && "#{dados[:micras]} µ") || (dados[:espessura_mm] && "#{dados[:espessura_mm]} mm")
    [ dados[:nome] || dados[:grupo], dados[:densidade], dados[:cor], medida, dados[:largura].to_s.tr(".", ",") ].compact.join(" · ")
  end
end
