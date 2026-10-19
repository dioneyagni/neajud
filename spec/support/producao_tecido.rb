require_relative "tecidos"
require_relative "producao_dtf"

# A confirmed tecido pedido for the production specs (Etapa 2.7c): a corrida
# of 12,5 m on a fabric 1,40 m wide, and a cor lisa of 3 m on one typed at
# 1,50 m — each its own item, so its own line.
# Usage: pedido = pedido_tecido_confirmado
#        gravar_original(pedido.itens_pedido.first.arquivo, "spec/fixtures/files/01.tif")
module ProducaoTecido
  def pedido_tecido_confirmado
    client = create(:client)
    pedido = create(:pedido, client: client, tipo: "tecido")
    oxford = criar_tecido(largura: "1.40")
    { "corrida" => [ 12.5, nil ], "cor_lisa" => [ 3, 1500 ] }.each do |tipo, (metros, largura)|
      arquivo = criar_obra_de_tecido(tipo, client: client).arquivos.first
      arquivo.update!(approved_version: create(:arquivo_version, arquivo: arquivo, approved: true, status: "processed"))
      create(:item_pedido, pedido: pedido, arquivo: arquivo, materia_prima: oxford, metros: metros, largura_mm: largura)
    end
    pedido.update!(status: "confirmado")
    pedido.reload
  end

  # The item's file name, as nome_completo gives it for the RIP.
  def titulo_do_item(item)
    item.arquivo.nome_completo(para_arquivo: true)
  end
end

RSpec.configure { |config| config.include ProducaoTecido }
