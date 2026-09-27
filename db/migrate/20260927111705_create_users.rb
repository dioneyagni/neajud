# Etapa 0.5 (1/3): the person's account. `User` is the plan's "pessoa"
# (name chosen in session, 27/09/2026). cloud_user_uuid links it to the
# Neajud Cloud account when that exists (Etapa 7.1).
class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :uuid, null: false
      t.string :nome, null: false
      t.string :email_address, null: false
      t.string :password_digest, null: false
      t.string :cloud_user_uuid

      t.timestamps
    end
    add_index :users, :uuid, unique: true
    add_index :users, :email_address, unique: true
    add_index :users, :cloud_user_uuid, unique: true
  end
end
