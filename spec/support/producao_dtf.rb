require_relative "etiquetas_dtf"

# A confirmed DTF pedido for the production specs (Etapa 2.6b2): one
# etiqueta, "P" standing (50 × 15 mm: 40 in 4 rows of 11) and "G" turned
# (100 × 30 mm: 18 across turned, one row, against 4 rows standing).
# Usage: pedido = pedido_dtf_confirmado(entrega: "rolo")
#        gravar_original(pedido.itens_pedido.first.arte.arquivos.last, "spec/fixtures/files/01.tif")
module ProducaoDtf
  def pedido_dtf_confirmado(entrega: "cortada", quantidades: { "P" => 40, "G" => 18 })
    client = create(:client)
    etiqueta = criar_etiqueta_dtf(client: client, tamanhos: { "P" => [ 591, 177 ], "G" => [ 1181, 354 ] })
    pedido = create(:pedido, client: client, tipo: "dtf", entrega: entrega)
    item = create(:item_pedido, pedido: pedido, arquivo: etiqueta.arquivos.first)
    quantidades.each { |tamanho, quantidade| item.grades.create!(tamanho_nome: tamanho, quantidade: quantidade) }
    EncaixeDoPedidoDtf.gravar!(pedido)
    pedido.update!(status: "confirmado")
    pedido.reload
  end

  # Puts a real file behind a size's version in use.
  def gravar_original(arquivo, fixture)
    versao = arquivo.approved_version
    versao.update_columns(original_file: File.basename(fixture))
    FileUtils.mkdir_p(File.dirname(versao.original_path))
    FileUtils.cp(fixture, versao.original_path)
  end

  def arquivo_do_tamanho(pedido, rotulo)
    pedido.itens_pedido.first.arte.arquivos.find { |a| a.rotulo_de_tamanho == rotulo }
  end
end

RSpec.configure { |config| config.include ProducaoDtf }
