# Rede editável 1/2 (decided 09/11/2026, Q1a/Q3a/Q8a): the dublagem network
# leaves config/dublagens.yml for the database — each ligação's groups by
# GrupoMaterial, the situações a table of their own — so the team can edit
# it (2/2). Each base layer keeps when its ligação dubs (camadas.dubla), so
# a construção in use keeps its momentos when the network changes.
#
# Up imports db/seeds/rede_de_dublagens.yml (only adds) and fills the
# momento of the layers already there from it; down drops the tables and the
# column (the network is back in the YAML of the commit before).
class RedeDeDublagensNoBanco < ActiveRecord::Migration[8.1]
  def change
    create_table :situacoes_dublagem do |t|
      t.string :uuid, null: false, index: { unique: true }
      # What Construcao#situacao keeps (tecido_molha).
      t.string :chave, null: false, index: { unique: true }
      t.string :nome, null: false
      t.timestamps
    end

    create_table :ligacoes_dublagem do |t|
      t.string :uuid, null: false, index: { unique: true }
      # The upper group first: the lado is its side.
      t.references :grupo_a, null: false, foreign_key: { to_table: :grupo_materiais }
      t.references :grupo_b, null: false, foreign_key: { to_table: :grupo_materiais }
      t.string :lado
      t.string :dubla, null: false
      t.json :a_confirmar, null: false, default: []
      t.timestamps
    end

    # A ligação's ligantes: the usual ones (no situação), or a situação's in
    # their place. micras: a list, or micras_minimo; neither, any.
    create_table :ligantes_da_ligacao do |t|
      t.references :ligacao_dublagem, null: false, foreign_key: { to_table: :ligacoes_dublagem }
      t.references :situacao_dublagem, foreign_key: { to_table: :situacoes_dublagem }
      t.references :grupo_material, null: false, foreign_key: true
      t.json :micras
      t.integer :micras_minimo
      t.integer :posicao, null: false
      t.timestamps
    end

    add_column :camadas_construcao, :dubla, :string

    reversible { |direcao| direcao.up { importar_e_preencher } }
  end

  private

  def importar_e_preencher
    [ SituacaoDublagem, LigacaoDublagem, LiganteDaLigacao, CamadaConstrucao ].each(&:reset_column_information)
    relatorio = ImportarRedeDeDublagens.new.call
    say "rede: created #{relatorio[:criados].join(", ").presence || "nothing"}"
    Construcao.includes(camadas: { materia_prima: :grupo_material }).find_each do |construcao|
      construcao.camadas_em_ordem.each_cons(2) do |acima, abaixo|
        abaixo.update_columns(dubla: acima.ligacao_com(abaixo.materia_prima)&.dubla)
      end
    end
  end
end
