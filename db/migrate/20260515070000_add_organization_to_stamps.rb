class AddOrganizationToStamps < ActiveRecord::Migration[8.1]
  def change
    change_table :stamps, bulk: true do |t|
      t.string :molde_nome, default: "New Mold"
      t.string :peca_nome, default: "New Piece"
      t.boolean :organized, default: false, null: false
    end
  end
end
