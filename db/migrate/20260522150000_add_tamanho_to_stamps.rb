class AddTamanhoToStamps < ActiveRecord::Migration[8.1]
  def change
    add_reference :stamps, :tamanho, foreign_key: true
  end
end
