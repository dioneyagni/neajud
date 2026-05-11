class CreateBans < ActiveRecord::Migration[8.1]
  def change
    create_table :bans do |t|
      t.string :uuid, null: false
      t.string :ip_address, null: false
      t.string :reason
      t.datetime :expires_at

      t.timestamps
    end

    add_index :bans, :uuid, unique: true
    add_index :bans, :ip_address
  end
end
