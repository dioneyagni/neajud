class AddClientRefToStamps < ActiveRecord::Migration[8.1]
  def change
    add_reference :stamps, :client, null: true, foreign_key: true
  end
end
