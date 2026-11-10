require "rails_helper"

# Rede editável 2/2a (Q3a): the histórico's line, field by field.
RSpec.describe MudancasDaLigacao do
  let(:antes) { { "lado" => "qualquer", "dubla" => "antes", "ligantes" => [ "Filme 25 µm" ], "situacoes" => { "Tecido molha" => [ "Filme PU" ] }, "a_confirmar" => [ "ligantes" ] } }

  it "says each change, short" do
    depois = { "lado" => "trama", "dubla" => "depois", "ligantes" => [ "Cola" ], "situacoes" => { "Vai frequência" => [ "Filme 35 µm" ] }, "a_confirmar" => [] }

    expect(described_class.new(antes, depois).texto).to eq("lado qualquer → trama; dubla antes → depois; tirou o ligante Filme 25 µm; pôs o ligante Cola; " \
                                                           "Tecido molha: Filme PU → os de cima; Vai frequência: os de cima → Filme 35 µm; a confirmar: ligantes → nenhum")
  end

  it "is empty when nothing changed" do
    expect(described_class.new(antes, antes.deep_dup).texto).to eq("")
  end
end
