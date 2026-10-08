require "rails_helper"

# Etapa 1.2 (3/3, parte 3a): the pedido page's matrix.
RSpec.describe PedidosHelper, type: :helper do
  let(:lateral) { create(:peca, nome: "Lateral") }
  let(:molde) { create(:molde, partes: [ lateral ]) }

  # An item of an arte whose molde's Lateral DXF serves 29 to 32 (the
  # product's grade, from the factory, is 18…46).
  def item_com_grade(grade)
    corte = create(:arquivo, :corte, organized: true, peca: lateral, client: molde.client, modelo: molde.modelo)
    corte.moldes << molde
    create(:tamanho, arquivo: corte, nome: "29-30", numeros: %w[29 30], position: 1)
    create(:tamanho, arquivo: corte, nome: "31-32", numeros: %w[31 32], position: 2)
    arte = create(:arquivo, molde: molde, client: molde.client, peca: lateral)
    create(:item_pedido, arquivo: arte).tap { |i| grade.each { |n, q| i.grades.create!(tamanho_nome: n, quantidade: q) } }
  end

  describe "#colunas_do_item" do
    it "takes the product's grade, showing the DXF numbers and any number already ordered" do
      colunas = helper.colunas_do_item(item_com_grade("26" => 1, "30" => 2))
      expect([ colunas.ordem, colunas.visiveis ]).to eq([ (18..46).map(&:to_s), %w[26 29 30 31 32] ])
    end

    it "has one column, the total, for an arte without molde" do
      item = create(:item_pedido, arquivo: create(:arquivo))
      expect(helper.colunas_do_item(item).to_h).to eq(ordem: [ "_total" ], visiveis: [ "_total" ])
    end
  end

  describe "#rotulo_do_numero" do
    it "names the total Qtd and keeps a number" do
      expect([ helper.rotulo_do_numero("_total"), helper.rotulo_do_numero("30") ]).to eq(%w[Qtd 30])
    end
  end

  describe "#estado_da_celula" do
    numero = ResolucaoDoItem::Numero

    it "tells an ordered number's pendência or origin, and whether a DXF serves an unordered one" do
      tamanho = build(:tamanho)
      estados = [
        numero.new(quantidade: 2, pendencia: :sem_arquivo, tamanho: tamanho),
        numero.new(quantidade: 2, origem: :piloto, tamanho: tamanho),
        numero.new(quantidade: 0, tamanho: tamanho),
        numero.new(quantidade: 0)
      ].map { |n| helper.estado_da_celula(n) }
      expect(estados).to eq(%i[sem_arquivo piloto livre vazio])
    end
  end

  describe "#arquivo_da_linha_de_impressao" do
    linha = ImpressaoPedidoService::Linha

    it "names the file, or what is missing" do
      arquivo = build(:arquivo, filename: "lat-esq", extension: "tif")
      textos = [
        linha.new(arquivo: arquivo), linha.new(pendencia: :sem_lado, lado: "direito"),
        linha.new(pendencia: :sem_arquivo), linha.new(pendencia: :sem_corte)
      ].map { |l| helper.arquivo_da_linha_de_impressao(l) }
      expect(textos).to eq([ "lat-esq.tif", "sem o arquivo DIR", "sem arquivo de produção", "nenhum corte organizado atende" ])
    end
  end

  describe "#falta_de_metragem_do_corte" do
    linha = ProducaoPedidoService::Linha

    it "says why a Corte line has no expected metragem" do
      corte = build(:arquivo, :corte)
      tamanho = build(:tamanho, arquivo: corte)
      textos = [ linha.new(tamanho: tamanho), linha.new(tamanho: tamanho, materia_prima: MateriaPrima.new) ].map { |l| helper.falta_de_metragem_do_corte(l) }
      corte.giro = "180"
      textos << helper.falta_de_metragem_do_corte(linha.new(tamanho: tamanho, materia_prima: MateriaPrima.new))
      expect(textos).to eq([ "sem material: sem metragem", "giro do corte não marcado", "metragem ainda não calculada" ])
    end
  end
end
