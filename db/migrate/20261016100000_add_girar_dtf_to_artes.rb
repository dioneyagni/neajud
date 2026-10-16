# The DTF etiqueta turns on the film only when the team marks it (decided
# 16/10/2026: the fit picked the orientation with fewer meters and turned
# too many). One mark for the whole etiqueta, every size; unmarked = standing.
class AddGirarDtfToArtes < ActiveRecord::Migration[8.1]
  def change
    add_column :artes, :girar_dtf, :boolean, default: false, null: false
  end
end
