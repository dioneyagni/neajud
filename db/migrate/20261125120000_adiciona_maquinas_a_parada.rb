# Máquinas 3/5a (decided 24/11/2026): a stop runs from a day to another
# (Q6a — the old ones end the day they start), stops one or more machines
# of its stage (Q1a: the whole machine), keeps what it did to the queue
# when saved (Q4a, for the bulletins to come), who made it, and when it
# came back to work and who said so (Q7a).
class AdicionaMaquinasAParada < ActiveRecord::Migration[8.1]
  def up
    add_column :excecoes_calendario, :data_fim, :date
    execute "UPDATE excecoes_calendario SET data_fim = data"
    change_column_null :excecoes_calendario, :data_fim, false
    add_index :excecoes_calendario, :data_fim
    add_column :excecoes_calendario, :impacto, :json
    add_reference :excecoes_calendario, :user, foreign_key: true, null: true
    add_column :excecoes_calendario, :voltou_em, :datetime
    add_reference :excecoes_calendario, :voltou_por, foreign_key: { to_table: :users }, null: true

    create_table :excecoes_calendario_maquinas do |t|
      t.references :excecao_calendario, null: false, foreign_key: { to_table: :excecoes_calendario }
      t.references :maquina, null: false, foreign_key: true
      t.timestamps
    end
    add_index :excecoes_calendario_maquinas, %i[excecao_calendario_id maquina_id], unique: true, name: "index_excecoes_maquinas_unicas"
  end

  def down
    drop_table :excecoes_calendario_maquinas
    remove_reference :excecoes_calendario, :voltou_por, foreign_key: { to_table: :users }
    remove_column :excecoes_calendario, :voltou_em
    remove_reference :excecoes_calendario, :user, foreign_key: true
    remove_column :excecoes_calendario, :impacto
    remove_index :excecoes_calendario, :data_fim
    remove_column :excecoes_calendario, :data_fim
  end
end
