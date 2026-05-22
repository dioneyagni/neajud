class AddForeignKeysToStamps < ActiveRecord::Migration[8.1]
  def change
    add_reference :stamps, :molde, foreign_key: true
    add_reference :stamps, :peca, foreign_key: true
    add_reference :stamps, :modelo, foreign_key: true
  end
end
