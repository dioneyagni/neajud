# Etapa 0.5 (1/3): one Empresa per instance (docs/plano.md, Etapa 2.1: one
# container per company), so data tables get no empresa_id. A vínculo links a
# user to the empresa with one or more fixed perfis; permissions come in 2/3.
class CreateEmpresasAndVinculos < ActiveRecord::Migration[8.1]
  def change
    create_table :empresas do |t|
      t.string :uuid, null: false
      t.string :nome, null: false
      t.timestamps
    end
    add_index :empresas, :uuid, unique: true

    create_table :vinculos do |t|
      t.string :uuid, null: false
      t.references :user, null: false, foreign_key: true
      t.references :empresa, null: false, foreign_key: true
      t.json :perfis, null: false, default: []
      t.timestamps
    end
    add_index :vinculos, :uuid, unique: true
    add_index :vinculos, %i[user_id empresa_id], unique: true
  end
end
