require "rails_helper"

# Rede editável 1/2 (decided 09/11/2026, Q8a): the initial network only adds
# what is missing; the file is checked before anything is written.
RSpec.describe ImportarRedeDeDublagens do
  def ligacao(**campos)
    { "par" => %w[Oxford Lona], "ligantes" => [ { "grupo" => "Filme", "micras" => { "min" => 35 } } ], "dubla" => "antes" }.merge(campos.transform_keys(&:to_s))
  end

  def papeis = { "Oxford" => { "superficie" => true, "base" => true, "estampavel" => "sim" },
             "Lona" => { "superficie" => false, "base" => true, "estampavel" => "nao" },
             "Filme" => { "superficie" => false, "base" => false, "estampavel" => "nao" },
             "Filme PU" => { "superficie" => false, "base" => false, "estampavel" => "nao" } }

  def rede(*ligacoes, grupos: papeis) = { "grupos" => grupos, "situacoes" => { "tecido_molha" => "Tecido molha" }, "ligacoes" => ligacoes }

  def importar(*ligacoes, **opcoes) = described_class.new(conteudo: rede(*ligacoes, **opcoes)).call

  it "imports db/seeds/rede_de_dublagens.yml: its ligações, ligantes and situações" do
    described_class.new.call
    expect(LigacaoDublagem.count).to eq(YAML.safe_load_file(described_class::ARQUIVO)["ligacoes"].size)
    expect(SituacaoDublagem.pluck(:chave)).to contain_exactly("vai_frequencia", "tecido_molha")
    expect(RedeDeDublagens.ligacao("Oxford", "Oxford").ligantes_na("tecido_molha").map(&:descricao)).to eq([ "Filme PU" ])
  end

  it "creates a missing group with the file's roles, asking what Materiais' new group asks" do
    relatorio = importar(ligacao("situacoes" => { "tecido_molha" => [ { "grupo" => "Filme PU" } ] }))
    expect(relatorio[:criados]).to include("Oxford", "Lona", "Filme", "Filme PU", "Oxford–Lona", "Situação tecido_molha")
    expect(GrupoMaterial.find_by!(nome: "Lona")).to have_attributes(superficie: false, base: true, estampavel: "nao", atributos: { "gramatura" => true })
    ligantes = LigacaoDublagem.sole.ligantes
    expect(ligantes.map { |l| [ l.grupo_material.nome, l.situacao_dublagem&.chave, l.micras_minimo, l.posicao ] }).to eq([ [ "Filme", nil, 35, 1 ], [ "Filme PU", "tecido_molha", nil, 2 ] ])
  end

  # Dublagem 5b2a: the file's Cola is counted in kg and asks its consumption.
  it "creates a missing group with the file's unit and attributes" do
    importar(ligacao("ligantes" => [ { "grupo" => "Cola" } ]), grupos: papeis.merge("Cola" => papeis["Filme"].merge("unidade" => "kg", "atributos" => { "consumo_g_m2" => true })))
    expect(GrupoMaterial.find_by!(nome: "Cola")).to have_attributes(unidade: "kg", atributos: { "consumo_g_m2" => true })
    expect(YAML.safe_load_file(described_class::ARQUIVO).dig("grupos", "Cola")).to include("unidade" => "kg", "atributos" => { "consumo_g_m2" => true })
  end

  it "never changes what is already there, and run again adds nothing" do
    oxford = GrupoMaterial.create!(nome: "oxford", superficie: true, base: false)
    importar(ligacao)
    LigacaoDublagem.sole.update!(dubla: "depois")
    SituacaoDublagem.sole.update!(nome: "Molha muito")

    relatorio = importar(ligacao("par" => %w[Lona Oxford]))
    expect(relatorio[:criados]).to be_empty
    expect(relatorio[:existentes]).to include("Situação tecido_molha", "Lona–oxford")
    expect([ LigacaoDublagem.sole.dubla, SituacaoDublagem.sole.nome, oxford.reload.base, LiganteDaLigacao.count ]).to eq([ "depois", "Molha muito", false, 1 ])
  end

  # Rede editável 2/2a: what the team sent to the trash stays there.
  it "counts a ligação in the trash as there, never bringing it back" do
    importar(ligacao)
    LigacaoDublagem.sole.excluir!(changed_by: "127.0.0.1")

    expect(importar(ligacao)[:existentes]).to include("Oxford–Lona")
    expect(LigacaoDublagem.sole).to be_excluido
  end

  it "adds a ligação of another lado next to the one for any side" do
    importar(ligacao)
    importar(ligacao("lado" => "avesso", "dubla" => "depois"))
    expect(LigacaoDublagem.order(:id).pluck(:lado, :dubla)).to eq([ [ nil, "antes" ], [ "avesso", "depois" ] ])
  end

  # 11/11/2026 (Q1a): the file may allow both momentos.
  it "imports a ligação that dubs antes e depois" do
    importar(ligacao("dubla" => "antes e depois"))
    expect(LigacaoDublagem.sole.dubla).to eq("antes e depois")
  end

  it "refuses a group neither registered nor in grupos, writing nothing" do
    expect { importar(ligacao, grupos: papeis.except("Lona")) }.to raise_error(described_class::Invalida, /group "Lona" is not registered and not in grupos/)
    expect([ GrupoMaterial.count, LigacaoDublagem.count, SituacaoDublagem.count ]).to eq([ 0, 0, 0 ])
  end

  describe "checking the file" do
    {
      "an unknown field" => [ { "cor" => "x" }, /unknown field "cor"/ ],
      "a pair of one" => [ { "par" => [ "Oxford" ] }, /par \["Oxford"\] must be two group names/ ],
      "a wrong dubla" => [ { "dubla" => "durante" }, /dubla "durante" is not one of antes, depois/ ],
      "a wrong lado" => [ { "lado" => "costas" }, /lado "costas" is not one of trama, avesso/ ],
      "no ligante" => [ { "ligantes" => [] }, /ligantes must list at least one ligante/ ],
      "micras not integer" => [ { "ligantes" => [ { "grupo" => "Filme", "micras" => [ "25" ] } ] }, /micras \["25"\] must be a list of positive integers/ ],
      "a situação not declared" => [ { "situacoes" => { "chove" => [ { "grupo" => "Cola" } ] } }, /situação "chove" is not one of tecido_molha/ ],
      "a wrong a_confirmar" => [ { "a_confirmar" => [ "preco" ] }, /a_confirmar "preco" is not one of/ ]
    }.each do |caso, (campos, mensagem)|
      it "refuses #{caso}, naming the ligação and the value" do
        expect { importar(ligacao(**campos.transform_keys(&:to_sym))) }.to raise_error(described_class::Invalida, /ligacao 1 .*#{mensagem.source}/)
        expect(GrupoMaterial.count).to eq(0)
      end
    end

    it "refuses the same pair twice, in any order" do
      expect { importar(ligacao, ligacao("par" => %w[Lona Oxford])) }.to raise_error(described_class::Invalida, /pair Lona–Oxford appears 2 times/)
    end

    it "refuses a group's unit or attributes it doesn't know" do
      expect { importar(ligacao, grupos: papeis.merge("Lona" => papeis["Lona"].merge("unidade" => "litro"))) }
        .to raise_error(described_class::Invalida, /grupo Lona: .*optionally unidade: m\|kg/)
      expect { importar(ligacao, grupos: papeis.merge("Lona" => papeis["Lona"].merge("atributos" => { "cor" => true }))) }
        .to raise_error(described_class::Invalida, /grupo Lona: /)
    end

    it "refuses a group's roles that aren't true/false and an estampavel option" do
      expect { importar(ligacao, grupos: papeis.merge("Lona" => { "superficie" => "sim", "base" => true, "estampavel" => "nao" })) }
        .to raise_error(described_class::Invalida, /grupo Lona: roles .*expected \{ superficie: true\|false/)
    end
  end
end
