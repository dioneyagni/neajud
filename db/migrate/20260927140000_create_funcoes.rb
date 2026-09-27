# Etapa 0.5 (2/4), decided 27/09/2026: the plan's fixed perfis become
# funções the dono edits (a grid of levels per área + special actions) and
# can create — many factory workers share one função. Each vínculo gets one
# função plus optional extra accesses (acessos_extras, used from 3/4).
#
# Existing vínculos keep their access: each perfil maps to the função of the
# same name, the strongest one winning (dono > admin > … ). Rollback maps back.
class CreateFuncoes < ActiveRecord::Migration[8.1]
  PADRAO = [
    { nome: "Dono", dono: true, niveis: {}, acoes: [] },
    { nome: "Admin", niveis: { pedidos: 3, clientes: 3, artes: 3, catalogo: 3, estoque: 3, lixeira: 0 }, acoes: %w[baixar_producao gerenciar_usuarios] },
    { nome: "Atendimento", niveis: { pedidos: 3, clientes: 3, artes: 3, catalogo: 1, estoque: 2, lixeira: 0 }, acoes: [] },
    { nome: "Designer", niveis: { pedidos: 1, clientes: 1, artes: 3, catalogo: 3, estoque: 0, lixeira: 0 }, acoes: %w[baixar_producao] },
    { nome: "Produção", niveis: { pedidos: 1, clientes: 0, artes: 1, catalogo: 1, estoque: 1, lixeira: 0 }, acoes: %w[baixar_producao] }
  ].freeze
  PERFIL_PARA_FUNCAO = { "dono" => "Dono", "admin" => "Admin", "atendimento" => "Atendimento",
                         "designer" => "Designer", "producao" => "Produção" }.freeze

  def up
    create_table :funcoes do |t|
      t.string :uuid, null: false
      t.string :nome, null: false
      t.boolean :dono, null: false, default: false
      t.json :niveis, null: false, default: {}
      t.json :acoes, null: false, default: []
      t.datetime :deleted_at
      t.integer :deleted_by_id
      t.datetime :restored_at
      t.integer :restored_by_id
      t.timestamps
    end
    add_index :funcoes, :uuid, unique: true
    add_index :funcoes, :nome, unique: true
    add_index :funcoes, :deleted_at

    add_reference :vinculos, :funcao, foreign_key: true
    add_column :vinculos, :acessos_extras, :json, null: false, default: {}
    migrar_perfis_para_funcoes if select_value("SELECT COUNT(*) FROM empresas").to_i.positive?
    remove_column :vinculos, :perfis
  end

  def down
    add_column :vinculos, :perfis, :json, null: false, default: []
    execute <<~SQL
      UPDATE vinculos SET perfis = json_array(
        CASE (SELECT nome FROM funcoes WHERE funcoes.id = vinculos.funcao_id)
          #{PERFIL_PARA_FUNCAO.map { |perfil, nome| "WHEN #{quote(nome)} THEN #{quote(perfil)}" }.join(" ")}
          ELSE 'producao' END)
    SQL
    remove_reference :vinculos, :funcao, foreign_key: true
    remove_column :vinculos, :acessos_extras
    drop_table :funcoes
  end

  private

  def migrar_perfis_para_funcoes
    agora = Time.current
    PADRAO.each do |funcao|
      insert_funcao(funcao, agora)
    end
    select_rows("SELECT id, perfis FROM vinculos").each do |id, perfis|
      nome = PERFIL_PARA_FUNCAO.values_at(*JSON.parse(perfis)).compact.min_by { |n| PADRAO.index { |f| f[:nome] == n } } || "Produção"
      execute "UPDATE vinculos SET funcao_id = (SELECT id FROM funcoes WHERE nome = #{quote(nome)}) WHERE id = #{id.to_i}"
    end
  end

  def insert_funcao(funcao, agora)
    execute <<~SQL
      INSERT INTO funcoes (uuid, nome, dono, niveis, acoes, created_at, updated_at)
      VALUES (#{quote(SecureRandom.uuid)}, #{quote(funcao[:nome])}, #{funcao[:dono] ? 1 : 0},
              #{quote(funcao[:niveis].to_json)}, #{quote(funcao[:acoes].to_json)}, #{quote(agora)}, #{quote(agora)})
    SQL
  end

  def quote(value)
    connection.quote(value)
  end
end
