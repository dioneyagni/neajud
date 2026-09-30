# Etapa 1.1 (3/5): the official catalog (config/catalogo_oficial.yml) is
# loaded after every db:prepare — the deploy entrypoint runs it — so a new
# instance, a deploy and a fresh development database all get the list.
namespace :catalogo do
  desc "Load config/catalogo_oficial.yml into the database (safe to repeat)"
  task sincronizar: :environment do
    resumo = CatalogoOficial.sincronizar!
    puts "Official catalog: #{resumo[:produtos]} produtos, #{resumo[:modelos]} modelos, #{resumo[:na_lixeira]} moved to the trash"
  end
end

Rake::Task["db:prepare"].enhance { Rake::Task["catalogo:sincronizar"].invoke }
