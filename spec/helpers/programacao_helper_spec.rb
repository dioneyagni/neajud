require "rails_helper"

# Painel 3/4a: the impact window's title and each line of a pedido's
# "Histórico da programação".
RSpec.describe ProgramacaoHelper, type: :helper do
  include ActiveSupport::Testing::TimeHelpers

  let(:pessoa) { create(:user, nome: "Dione") }
  let(:movido) { create(:pedido, tipo: "tecido") }
  let(:empurrado) { create(:pedido, tipo: "tecido") }

  before do
    def helper.cliente_final? = false
    travel_to Time.zone.parse("2026-11-05 14:20")
  end

  def movimento(**dados)
    MovimentoDaFila.create!(pedido: movido, user: pessoa, etapa: "impressao", setor: "impressao", de: 3, para: 1, ordem_em: 1.hour.ago, **dados)
  end

  it "says a move to its pedido, to the ones it pushed, and a move back" do
    m = movimento(motivo: "cliente pediu urgência", empurrados: [ { "pedido_id" => empurrado.id, "de" => "2026-11-12T15:30:00-03:00", "para" => "2026-11-13T09:00:00-03:00" } ])
    numero = "##{movido.uuid.first(8)}"

    expect(helper.linha_do_historico(m, movido)).to eq("05/11 14:20 · Dione passou o #{numero} à frente na Impressão (3º → 1º) · cliente pediu urgência · passou à frente de 2 pedidos")
    expect(helper.linha_do_historico(m, empurrado)).to eq("05/11 14:20 · Dione passou o #{numero} à frente na Impressão (3º → 1º) · cliente pediu urgência · este pedido: qui 12/11 15:30 → sex 13/11 09:00")
    expect(helper.linha_do_historico(movimento(de: 1, para: 3, ordem_em: nil), movido)).to eq("05/11 14:20 · Dione voltou o #{numero} à ordem de chegada na Impressão")
    expect(helper.previsao_do_impacto(nil)).to eq("sem previsão")
  end

  it "titles the window by the move" do
    vez = FilaDeProducao::Vez.new(pedido: movido, etapa: EtapasProducao.etapa("tecido", "impressao"))
    titulos = [ [ :posicao, 3, 1 ], [ :chegada, 1, 3 ] ].map { |tipo, de, para| helper.titulo_do_impacto(ImpactoDoMovimento::Impacto.new(tipo: tipo, vez: vez, de: de, para: para, setor: "impressao")) }
    titulos << helper.titulo_do_impacto(ImpactoDoMovimento::Impacto.new(tipo: :setor, setor: "impressao", movimentos: [ 1, 2 ]))
    expect(titulos).to eq([ "##{movido.uuid.first(8)} · Impressão: 3º → 1º", "##{movido.uuid.first(8)} · Impressão: voltar à ordem de chegada (1º → 3º)",
                            "Fila da Impressão: voltar tudo à ordem de chegada (2 movidas)" ])
  end
end
