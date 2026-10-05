require "rails_helper"

# Etapa 1.2 (2/3): an arte is an envelope of files, one per part × size; the
# arte's fields (molde, client, referência, nome) are the same in all of them.
RSpec.describe MembroDeArte do
  around do |example|
    ActiveJob::Base.queue_adapter = :test
    example.run
  ensure
    ActiveJob::Base.queue_adapter = :inline
  end

  let(:client) { create(:client) }
  let(:molde) { create(:molde, client: client) }

  def irmao_de(arquivo, **atributos)
    create(:arquivo, arte: arquivo.arte, **arquivo.attributes.slice(*MembroDeArte::CAMPOS_DA_ARTE).symbolize_keys, **atributos)
  end

  it "gives every new arte file an arte of its own, and none to a corte" do
    expect([ create(:arquivo).arte, create(:arquivo, :corte).arte ]).to match([ an_instance_of(Arte), nil ])
  end

  describe "#compartilhar_com_a_arte!" do
    it "takes a new molde, client and name to the other files of the arte" do
      arquivo = create(:arquivo)
      outro = irmao_de(arquivo)
      arquivo.update!(molde: molde, nome: "Bluey Azul")
      expect(outro.reload.attributes.values_at("molde_id", "client_id", "nome")).to eq([ molde.id, client.id, "Bluey Azul" ])
    end

    it "makes the other files drop a size of the old molde and look for theirs" do
      corte = create(:arquivo, :corte, organized: true, client: client, modelo: molde.modelo).tap { |c| c.moldes << molde }
      arquivo = create(:arquivo, molde: molde)
      outro = irmao_de(arquivo, tamanho: create(:tamanho, arquivo: corte))
      novo = create(:molde, client: client)
      expect { arquivo.update!(molde: novo) }.to have_enqueued_job(TamanhoAutoAssignJob).with(outro.id)
      expect(outro.reload.tamanho_id).to be_nil
    end

    it "also follows a referência read from the file name (written with update_columns)" do
      create(:peca, nome: "Língua")
      arquivo = create(:arquivo, filename: "19-BLUEY PTO-LINGUA", molde: molde)
      outro = irmao_de(arquivo)
      arquivo.ajustar_referencia_e_nome!
      expect([ outro.reload.referencia&.nome, outro.nome ]).to eq([ "19", "BLUEY PTO" ])
    end

    it "keeps part and size per file" do
      lateral, lingua = create(:peca), create(:peca)
      arquivo = create(:arquivo, peca: lateral, tamanho_rotulo: "29-30")
      outro = irmao_de(arquivo, peca: lingua, tamanho_rotulo: "31-32")
      arquivo.update!(nome: "Gato")
      expect(outro.reload.attributes.values_at("peca_id", "tamanho_rotulo")).to eq([ lingua.id, "31-32" ])
    end
  end

  it "lists one file per arte (its first) with .principais_das_artes" do
    arquivo = create(:arquivo)
    irmao_de(arquivo)
    sozinho = create(:arquivo)
    corte = create(:arquivo, :corte)
    expect(Arquivo.principais_das_artes.order(:id)).to eq([ arquivo, sozinho, corte ])
  end

  describe "#separar_da_arte!" do
    it "moves the file to an arte of its own, keeping its fields" do
      arquivo = create(:arquivo, molde: molde)
      outro = irmao_de(arquivo)
      outro.separar_da_arte!
      expect([ outro.reload.arte_id == arquivo.arte_id, outro.molde_id ]).to eq([ false, molde.id ])
    end

    it "refuses the only file of an arte" do
      expect { create(:arquivo).separar_da_arte! }.to raise_error(ArgumentError, /only file of its arte/)
    end
  end

  describe "#artes_para_juntar and #mesma_arte_em_outro_envelope" do
    it "offers the molde's other artes, and points out the one with the same name" do
      referencia = Referencia.do_molde!(molde, "19")
      arquivo = create(:arquivo, molde: molde, referencia: referencia, nome: "Bluey Azul")
      mesma = create(:arquivo, molde: molde, referencia: referencia, nome: "BLUEY AZUL")
      outra = create(:arquivo, molde: molde, referencia: referencia, nome: "Gato")
      create(:arquivo, molde: create(:molde, client: client), nome: "Bluey Azul")
      expect(arquivo.artes_para_juntar).to contain_exactly(mesma, outra)
      expect(arquivo.mesma_arte_em_outro_envelope).to eq([ mesma ])
    end
  end

  it "shows the corte's size once known, else the one read from the file name" do
    corte = create(:arquivo, :corte)
    expect([ create(:arquivo, tamanho_rotulo: "30").rotulo_de_tamanho,
             create(:arquivo, tamanho_rotulo: "30", tamanho: create(:tamanho, arquivo: corte, nome: "29-30")).rotulo_de_tamanho ]).to eq(%w[30 29-30])
  end
end
