# Names the DTFs and corridas uploaded before they were named from their file
# name (decided 14/10/2026; new ones are named on upload). Safe to repeat: a
# name already there is kept.
#
# Usage: bin/rails artes:nomear_sem_corte
namespace :artes do
  desc "Name the DTFs and corridas without a name from their file name"
  task nomear_sem_corte: :environment do
    artes = Arte.where(tipo: TipoDaArte::PREFIXOS.keys)
    artes.find_each { |arte| arte.principal&.nomear_pelo_arquivo! }
    puts "#{artes.count} works without corte named from their file names."
  end
end
