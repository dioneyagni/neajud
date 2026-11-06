# Painel 2/4a (decided 05/11/2026): the factory's turnos, the days or turnos
# it doesn't work (the whole factory or one stage) and each stage's rhythm
# per hour, by pedido type — what the queue and the previsão (2/4b) run on.
# New tables only: no data changes.
class TurnosERitmo < ActiveRecord::Migration[8.1]
  def change
    create_table :turnos do |t|
      t.string :uuid, null: false
      t.string :nome, null: false
      # Minutes after midnight; fim <= inicio crosses midnight (22:00–06:00).
      t.integer :inicio_min, null: false
      t.integer :fim_min, null: false
      # Days of the week it starts on, 0 = Sunday (Date#wday).
      t.json :dias, default: [], null: false
      t.datetime :deleted_at
      t.integer :deleted_by_id
      t.datetime :restored_at
      t.integer :restored_by_id
      t.timestamps
    end
    add_index :turnos, :uuid, unique: true

    create_table :excecoes_calendario do |t|
      t.string :uuid, null: false
      t.date :data, null: false
      t.string :nome, null: false
      # nil = the whole day; else only that turno's occurrence starting on data.
      t.references :turno, foreign_key: true
      # nil = the whole factory; else one stage's key (config/etapas_producao.yml).
      t.string :etapa
      # manual, or feriado (a national holiday the dono confirmed).
      t.string :origem, default: "manual", null: false
      t.timestamps
    end
    add_index :excecoes_calendario, :uuid, unique: true
    add_index :excecoes_calendario, :data

    create_table :ritmos_producao do |t|
      t.string :uuid, null: false
      t.string :tipo, null: false
      t.string :etapa, null: false
      # In the stage's baixa unit (m, peças, unidades) per hour.
      t.decimal :por_hora, precision: 10, scale: 3
      # The dono keeps his value even when the measured one has enough data.
      t.boolean :fixar_informado, default: false, null: false
      t.timestamps
    end
    add_index :ritmos_producao, :uuid, unique: true
    add_index :ritmos_producao, %i[tipo etapa], unique: true
  end
end
