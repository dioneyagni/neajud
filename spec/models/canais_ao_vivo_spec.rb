require "rails_helper"

# Etapa 2.8 (3b, decided 11/10/2026): who receives each live update. The gallery
# cards went to one stream for everyone — a cliente final got every client's.
RSpec.describe CanaisAoVivo do
  let(:alfa) { create(:client, name: "Alfa") }
  let(:beta) { create(:client, name: "Beta") }
  let(:molde_beta) { create(:molde, client: beta) }

  def cliente_final(client)
    create(:vinculo, user: create(:user), client: client).user
  end

  describe ".dos_cartoes_de" do
    it "sends an arte's card to the team and its own client only" do
      arte = create(:arquivo, client: alfa)
      expect(described_class.dos_cartoes_de(arte)).to eq([ "cartoes:equipe", "cartoes:#{alfa.uuid}" ])
    end

    it "sends a file without client to the team only" do
      expect(described_class.dos_cartoes_de(create(:arquivo))).to eq([ "cartoes:equipe" ])
    end

    it "sends a corte to the clients of its moldes while their cortes are open" do
      corte = create(:arquivo, :corte)
      ArquivoMolde.create!(arquivo: corte, molde: molde_beta)
      expect(described_class.dos_cartoes_de(corte)).to eq([ "cartoes:equipe" ])

      beta.update!(visibilidade: { "cortes" => true })
      expect(described_class.dos_cartoes_de(corte)).to eq([ "cartoes:equipe", "cartoes:#{beta.uuid}" ])
    end
  end

  describe ".do_registro" do
    it "names the stream by uuid, never Turbo's gid with the integer id" do
      pedido = create(:pedido)
      expect(described_class.do_registro(pedido)).to eq("pedido:#{pedido.uuid}")
    end

    it "raises for a model without a live stream" do
      expect { described_class.do_registro(create(:client)) }.to raise_error(ArgumentError, /Client has no live stream/)
    end
  end

  describe ".permitido?" do
    it "gives the team's cards to the team, never to a cliente final" do
      expect(described_class.permitido?(create(:vinculo).user, "cartoes:equipe")).to be(true)
      expect(described_class.permitido?(cliente_final(alfa), "cartoes:equipe")).to be(false)
    end

    it "gives a client's cards to its own people only" do
      expect(described_class.permitido?(cliente_final(alfa), "cartoes:#{alfa.uuid}")).to be(true)
      expect(described_class.permitido?(cliente_final(beta), "cartoes:#{alfa.uuid}")).to be(false)
    end

    it "gives a page's refreshes only while Visibilidade shows its record" do
      arte = create(:arquivo, client: alfa)
      expect(described_class.permitido?(cliente_final(alfa), "arquivo:#{arte.uuid}")).to be(true)
      expect(described_class.permitido?(cliente_final(beta), "arquivo:#{arte.uuid}")).to be(false)
      expect(described_class.permitido?(cliente_final(beta), "pedido:#{create(:pedido, client: alfa).uuid}")).to be(false)
    end

    it "refuses an unknown or incomplete name" do
      user = create(:vinculo).user
      expect(described_class.permitido?(user, "arquivos")).to be(false)
      expect(described_class.permitido?(user, "client:#{alfa.uuid}")).to be(false)
    end
  end

  it "signs with its own verifier: Turbo's signature is not accepted" do
    expect(described_class.ler(described_class.assinar("cartoes:equipe"))).to eq("cartoes:equipe")
    expect(described_class.ler(Turbo::StreamsChannel.signed_stream_name("cartoes:equipe"))).to be_nil
  end
end
