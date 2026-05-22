class AddMoldeToModelos < ActiveRecord::Migration[8.1]
  def change
    add_reference :modelos, :molde, foreign_key: true
  end
end
