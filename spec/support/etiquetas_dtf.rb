# An etiqueta DTF with measured sizes (Etapa 2.6b1): one file per size, its
# version in use processed with pixels and DPI, so EncaixeDaEtiqueta fits it.
# Usage: etiqueta = criar_etiqueta_dtf(client: c, tamanhos: { "P" => [191, 201], "G" => [400, 400] })
#        etiqueta.arquivos.first.encaixe_dtf["em_pe"]["por_fileira"] # => 32
module EtiquetasDtf
  def criar_etiqueta_dtf(client: nil, tamanhos: { "P" => [ 191, 201 ] }, dpi: 300, no_catalogo: false, girar_dtf: false)
    Empresa.atual || create(:empresa)
    arte = Arte.new(tipo: "dtf", no_catalogo: no_catalogo, girar_dtf: girar_dtf).tap(&:save!)
    tamanhos.each { |rotulo, (largura, altura)| arquivo_medido(arte, client, rotulo, largura, altura, dpi) }
    arte.reload
  end

  def arquivo_medido(arte, client, rotulo, largura, altura, dpi)
    arquivo = create(:arquivo, arte: arte, client: client, tamanho_rotulo: rotulo, filename: "dtf-#{rotulo}")
    versao = create(:arquivo_version, arquivo: arquivo, approved: true, status: "processing")
    ArquivoImageMetadata.create!(arquivo_version: versao, width_px: largura, height_px: altura, dpi: dpi)
    arquivo.update!(approved_version: versao)
    versao.update!(status: "processed")
    arquivo
  end
end

RSpec.configure { |config| config.include EtiquetasDtf }
