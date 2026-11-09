# Rede editável 1/2 (decided 09/11/2026, Q8a): adds the initial dublagem
# network (db/seeds/rede_de_dublagens.yml) — only what is missing; a
# ligação, situação or group already there is never changed. On the
# development database, take a bin/dev-backup first.
#
# Usage: bin/rails rede:importar
namespace :rede do
  desc "Add the initial dublagem network to the database (only what is missing)"
  task importar: :environment do
    relatorio = ImportarRedeDeDublagens.new.call
    puts "rede — created: #{relatorio[:criados].join(", ").presence || "nothing"}"
    puts "rede — already there: #{relatorio[:existentes].join(", ").presence || "nothing"}"
  end
end
