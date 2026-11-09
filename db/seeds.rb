# This file should ensure the existence of records required to run the application in every environment
# (production, development, test). The code here should be idempotent so that it can be executed at any
# point in every environment. The data can then be loaded with the bin/rails db:seed command
# (or created alongside the database with db:setup).
#
# No seed data: GrupoMaterial, CorMaterial and Client are all managed through the app itself
# (Materiais page "+ Register new" dialogs, /clients) — there is nothing that must exist
# before the app can be used. Colors are capped to CorMaterial::COLOR_HEX's known names via
# the "Register New Color" dialog; groups and clients are freeform.
#
# Rede editável 1/2 (decided 09/11/2026, Q8a): the one exception — a new instance starts with the
# initial dublagem network (db/seeds/rede_de_dublagens.yml), once, when db:prepare creates its
# database. Only adds what is missing. Not in the test environment: RSpec and bin/e2e reload the
# seeds after every truncation, and each RSpec spec that needs the network imports it
# (spec/support/construcoes.rb); bin/e2e runs `bin/rails rede:importar` itself.
ImportarRedeDeDublagens.new.call unless Rails.env.test?
