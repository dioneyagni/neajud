# Etapa 2.5c (decided 12/10/2026): a work without corte has no part, side or
# piloto — each of its files is the editable one —, and a corrida or a cor
# lisa no size (sold by the meter). The files uploaded before kept the part
# read from their names; from now on MembroDeArte clears them on save. Only
# dev samples have them, and no pedido uses these artes (only calçado goes
# into one until Etapas 2.6/2.7). Plain SQL: the models' rules may change.
class LimparPecasDasObrasSemCorte < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE arquivos SET peca_id = NULL, lado = NULL, papel = 'producao'
      WHERE arte_id IN (SELECT id FROM artes WHERE tipo <> 'calcado')
    SQL
    execute <<~SQL
      UPDATE arquivos SET tamanho_id = NULL, tamanho_rotulo = NULL
      WHERE arte_id IN (SELECT id FROM artes WHERE tipo IN ('corrida', 'cor_lisa'))
    SQL
  end

  # What was cleared was never these works' data: nothing to bring back.
  def down; end
end
