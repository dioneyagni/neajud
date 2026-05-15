class AddOrganizationToStamps < ActiveRecord::Migration[8.1]
  def change
    change_table :stamps, bulk: true do |t|
      t.string :molde_nome, default: "Novo Molde"
      t.string :peca_nome, default: "Nova Peça"
      t.boolean :organized, default: false, null: false
    end
  end
end
