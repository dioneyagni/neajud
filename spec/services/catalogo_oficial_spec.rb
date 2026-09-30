require "rails_helper"

RSpec.describe CatalogoOficial do
  let(:u_calcado) { SecureRandom.uuid }
  let(:u_jogging) { SecureRandom.uuid }
  let(:u_tenis) { SecureRandom.uuid }

  def lista(modelos: [ { "uuid" => u_jogging, "nome" => "Jogging", "abreviacao" => "JGG" } ], grade: { "de" => 18, "ate" => 20 })
    { "produtos" => [ { "uuid" => u_calcado, "nome" => "Calçado", "grade" => grade, "modelos" => modelos } ] }
  end

  def sincronizar(dados = lista)
    described_class.new(dados).sincronizar!
  end

  it "creates the produtos and modelos with the fixed uuids, grade and abbreviation" do
    expect(sincronizar).to eq(produtos: 1, modelos: 1, na_lixeira: 0)
    jogging = Modelo.find_by!(uuid: u_jogging)
    expect([ jogging.nome, jogging.abreviacao, jogging.produto.uuid, jogging.grade ])
      .to eq([ "Jogging", "JGG", u_calcado, %w[18 19 20] ])
  end

  it "keeps a grade given as a list, as strings" do
    sincronizar(lista(grade: %w[PP P M]))
    expect(Produto.find_by!(uuid: u_calcado).grade).to eq(%w[PP P M])
  end

  it "is safe to run again: nothing duplicated, changes applied in place" do
    sincronizar
    sincronizar(lista(modelos: [ { "uuid" => u_jogging, "nome" => "Jogging", "abreviacao" => "JOG" } ]))
    expect(Modelo.where(uuid: u_jogging).pluck(:abreviacao)).to eq([ "JOG" ])
    expect([ Produto.count, Modelo.count ]).to eq([ 1, 1 ])
  end

  # Never deleted: moldes may use it. Listed again, it comes back.
  it "sends to the trash what left the list, and restores it when listed again" do
    sincronizar(lista(modelos: [ { "uuid" => u_jogging, "nome" => "Jogging", "abreviacao" => "JGG" },
                                 { "uuid" => u_tenis, "nome" => "Tenis", "abreviacao" => "TNS" } ]))
    molde = create(:molde, modelo: Modelo.find_by!(uuid: u_tenis))

    expect(sincronizar[:na_lixeira]).to eq(1)
    tenis = Modelo.find_by!(uuid: u_tenis)
    expect(tenis).to be_excluido
    expect(tenis.exclusao_logs.last.changed_by).to eq(CatalogoOficial::AUTORIA)
    expect(molde.reload.modelo).to eq(tenis)

    sincronizar(lista(modelos: [ { "uuid" => u_tenis, "nome" => "Tenis", "abreviacao" => "TNS" } ]))
    expect(tenis.reload).not_to be_excluido
  end

  # A development sample typed before the list existed keeps its moldes.
  it "adopts a record with the same name that isn't in the list, and trashes unlisted ones" do
    amostra = create(:modelo, nome: "jogging", abreviacao: nil, produto: nil)
    antigo = create(:modelo, nome: "Tenis Baixo", abreviacao: nil, produto: nil)
    molde = create(:molde, modelo: amostra)

    sincronizar

    expect(amostra.reload).to have_attributes(uuid: u_jogging, nome: "Jogging", abreviacao: "JGG")
    expect(molde.reload.modelo).to eq(amostra)
    expect(antigo.reload).to be_excluido
  end

  it "refuses a malformed list, saying what is wrong" do
    expect { described_class.new({}) }.to raise_error(CatalogoOficial::ListaInvalida, /Expected a "produtos:" list/)
    sem_abreviacao = lista(modelos: [ { "uuid" => u_jogging, "nome" => "Jogging" } ])
    expect { sincronizar(sem_abreviacao) }.to raise_error(CatalogoOficial::ListaInvalida, /Missing "abreviacao"/)
    expect { sincronizar(lista(grade: "18-46")) }.to raise_error(CatalogoOficial::ListaInvalida, /must be a list or \{ de:, ate: \}; got "18-46"/)
  end

  describe "the shipped list (config/catalogo_oficial.yml)" do
    it "loads the catalog decided on 30/09/2026" do
      expect(described_class.sincronizar!).to eq(produtos: 3, modelos: 9, na_lixeira: 0)
      calcado = Produto.find_by!(nome: "Calçado")
      expect(calcado.grade.values_at(0, -1)).to eq(%w[18 46])
      expect(calcado.modelos.order(:abreviacao).pluck(:abreviacao)).to eq(%w[BT CHN CHT CLCF JGG SLD TNS])
      expect(Produto.find_by!(nome: "Camisa").grade).to eq(%w[PP P M G GG XG])
      expect(Produto.find_by!(nome: "Banner").grade).to eq([])
    end
  end
end
