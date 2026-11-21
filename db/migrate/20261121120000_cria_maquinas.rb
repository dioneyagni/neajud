# Máquinas 1/5 (decided 20/11/2026): the factory's machines, what each one
# does (a trabalho of TrabalhosDeMaquina) at what speed, and its histórico.
# Only new tables: nothing existing is moved (Q7a — no machine, as today).
class CriaMaquinas < ActiveRecord::Migration[8.1]
  def change
    create_table :maquinas do |t|
      t.string :uuid, null: false
      t.string :nome, null: false
      t.datetime :deleted_at
      t.integer :deleted_by_id
      t.datetime :restored_at
      t.integer :restored_by_id
      t.timestamps
      t.index :uuid, unique: true
    end

    # por_hora: the speed in the trabalho's unit; the Corte do calçado's is
    # its cutting machine's parameters instead (blank = RitmoProducao::MAQUINA_PADRAO).
    create_table :trabalhos_da_maquina do |t|
      t.string :uuid, null: false
      t.references :maquina, null: false, foreign_key: true
      t.string :trabalho, null: false
      t.decimal :por_hora, precision: 10, scale: 3
      t.decimal :velocidade_mm_s, precision: 10, scale: 3
      t.decimal :pinca_s, precision: 10, scale: 3
      t.decimal :preparo_min, precision: 10, scale: 3
      t.decimal :recolhimento_pecas_min, precision: 10, scale: 3
      t.decimal :troca_min, precision: 10, scale: 3
      t.timestamps
      t.index :uuid, unique: true
      t.index %i[maquina_id trabalho], unique: true
    end

    create_table :alteracoes_da_maquina do |t|
      t.string :uuid, null: false
      t.references :maquina, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.text :texto, null: false
      t.timestamps
      t.index :uuid, unique: true
    end
  end
end
