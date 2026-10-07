# Etapa 2.2 (1/3): fills the meters per piece of the sizes that already exist
# (new ones get it when their DXF is prepared). Safe to repeat: a width
# already computed is kept.
#
# Usage: bin/rails producao:metros_por_peca
namespace :producao do
  desc "Queue every size's meters per piece on the materials' widths"
  task metros_por_peca: :environment do
    larguras = MateriaPrima.larguras_mm
    ids = Tamanho.joins(:arquivo).merge(Arquivo.ativos).ids
    MetrosPorPecaJob.perform_later(ids, larguras)
    puts "Queued #{ids.size} sizes × widths #{larguras.inspect} mm."
  end
end
