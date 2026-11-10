require "rails_helper"
require_relative "../support/construcoes"

# Rede editável 2/2a (decided 10/11/2026): saving a ligação from its page.
RSpec.describe SalvarLigacao do
  before { importar_rede_de_dublagens }

  let(:grupo) { ->(nome) { GrupoMaterial.find_by!(nome: nome) } }
  let(:usuario) { create(:user) }
  let(:salvar) { ->(ligacao, dados) { described_class.new(ligacao, dados, grupos: GrupoMaterial.all, situacoes: SituacaoDublagem.all, user: usuario).call } }

  it "creates a ligação with its ligantes and a situação's, and a 'criou' line" do
    ligacao = LigacaoDublagem.new
    dados = { grupo_a_uuid: grupo.("Lona").uuid, grupo_b_uuid: grupo.("EVA").uuid, lado: "", dubla: "depois", a_confirmar: [ "", "ligantes" ],
              ligantes: [ { grupo_uuid: grupo.("Filme").uuid, micras: "25, 35" }, { grupo_uuid: "", micras: "" } ],
              situacoes: { "tecido_molha" => [ { grupo_uuid: grupo.("Filme PU").uuid, micras: "200 ou mais" } ] } }

    expect(salvar.(ligacao, dados)).to be(true), ligacao.errors.full_messages.to_sentence
    expect(ligacao.reload.resumo).to eq("lado" => "qualquer", "dubla" => "depois", "ligantes" => [ "Filme 25 ou 35 µm" ],
                                        "situacoes" => { "Tecido molha" => [ "Filme PU 200 µm ou mais" ] }, "a_confirmar" => [ "ligantes" ])
    expect(ligacao.alteracoes.map { |linha| [ linha.texto, linha.user ] }).to eq([ [ "criou", usuario ] ])
    expect(RedeDeDublagens.ligacao("EVA", "Lona").dubla).to eq("depois")
  end

  # Q4a: the groups are chosen only when it is new.
  it "edits what changed into one histórico line, never the groups" do
    ligacao = LigacaoDublagem.do_par(grupo.("Oxford"), grupo.("Lona")).sole
    dados = { grupo_a_uuid: grupo.("EVA").uuid, lado: "trama", dubla: "depois", a_confirmar: [],
              ligantes: [ { grupo_uuid: grupo.("Cola").uuid, micras: "" } ] }

    expect(salvar.(ligacao, dados)).to be(true), ligacao.errors.full_messages.to_sentence
    expect(ligacao.reload.grupo_a).to eq(grupo.("Oxford"))
    expect(ligacao.alteracoes.sole.texto).to eq("lado qualquer → trama; dubla antes → depois; tirou o ligante Filme 35 µm ou mais; pôs o ligante Cola; " \
                                                "Tecido molha: Filme PU → os de cima; a confirmar: situações → nenhum")
  end

  it "writes no line when nothing changed" do
    ligacao = LigacaoDublagem.do_par(grupo.("Oxford"), grupo.("EVA")).sole
    dados = { lado: "", dubla: "antes", a_confirmar: [ "situacoes" ], ligantes: [ { grupo_uuid: grupo.("Filme").uuid, micras: "25" } ],
              situacoes: { "tecido_molha" => [ { grupo_uuid: grupo.("Filme PU").uuid, micras: "" } ] } }

    expect(salvar.(ligacao, dados)).to be(true), ligacao.errors.full_messages.to_sentence
    expect(ligacao.alteracoes).to be_empty
  end

  it "refuses with the reasons and writes nothing: no groups, no ligante, micras it can't read, a pair already there" do
    nova = LigacaoDublagem.new
    expect(salvar.(nova, { dubla: "antes", ligantes: [ { grupo_uuid: grupo.("Filme").uuid, micras: "muito" } ] })).to be(false)
    expect(nova.errors.full_messages).to include("escolha os dois grupos", a_string_including('micras "muito" de Filme: esperado vazio (qualquer)'))

    repetida = LigacaoDublagem.new
    expect(salvar.(repetida, { grupo_a_uuid: grupo.("Lona").uuid, grupo_b_uuid: grupo.("Oxford").uuid, dubla: "antes", ligantes: [] })).to be(false)
    expect(repetida.errors.full_messages).to include("escolha ao menos um ligante", "Lona com Oxford já está na rede; cada par entra uma vez com o mesmo lado, em qualquer ordem")
    expect(AlteracaoDaRede.count).to eq(0)
  end
end
