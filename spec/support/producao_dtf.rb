require_relative "etiquetas_dtf"

# A confirmed DTF pedido for the production specs (Etapa 2.6b2): two
# etiquetas, each its own item — "P" standing (50 × 15 mm: 40 in 4 rows of
# 11) and "G" marked to turn (100 × 30 mm: 18 across turned, one row). One
# mark per etiqueta (decided 16/10/2026), so they can't share one.
# Usage: pedido = pedido_dtf_confirmado(entrega: "rolo")
#        gravar_original(pedido.itens_pedido.first.arte.arquivos.last, "spec/fixtures/files/01.tif")
module ProducaoDtf
  def pedido_dtf_confirmado(entrega: "cortada", quantidades: { "P" => 40, "G" => 18 })
    client = create(:client)
    pedido = create(:pedido, client: client, tipo: "dtf", entrega: entrega)
    { "P" => [ [ 591, 177 ], false ], "G" => [ [ 1181, 354 ], true ] }.each do |rotulo, (medida, girar)|
      next unless quantidades[rotulo]

      etiqueta = criar_etiqueta_dtf(client: client, tamanhos: { rotulo => medida }, girar_dtf: girar)
      create(:item_pedido, pedido: pedido, arquivo: etiqueta.arquivos.first).grades.create!(tamanho_nome: rotulo, quantidade: quantidades[rotulo])
    end
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
    pedido.itens_pedido.flat_map { |item| item.arte.arquivos.to_a }.find { |a| a.rotulo_de_tamanho == rotulo }
  end

  # The size's file name without the size: "DTF-2_dtf" (each size is its own etiqueta here).
  def titulo_do_tamanho(pedido, rotulo)
    arquivo_do_tamanho(pedido, rotulo).nome_completo(para_arquivo: true).delete_suffix("_#{rotulo}")
  end
end

RSpec.configure { |config| config.include ProducaoDtf }
