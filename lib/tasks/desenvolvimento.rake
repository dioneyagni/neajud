# The development database's starting groups and materials (decided
# 28/10/2026): a snapshot first (bin/dev-backup), then only adds what is
# missing — db/seeds.rb stays empty, so no instance starts with them.
#
# Usage: bin/rails dev:semear
namespace :dev do
  desc "Add the development database's starting groups and materials (only what is missing)"
  task semear: :environment do
    abort "dev:semear only runs in development; this is #{Rails.env.inspect}" unless Rails.env.development?

    system(Rails.root.join("bin/dev-backup").to_s, "antes-semear", exception: true)
    relatorio = SemeadorDeDesenvolvimento.new.call
    puts "criado: #{relatorio[:criados].join(", ").presence || "nada"}"
    puts "já existia: #{relatorio[:existentes].join(", ").presence || "nada"}"
  end
end
