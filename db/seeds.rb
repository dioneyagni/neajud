# This file should ensure the existence of records required to run the application in every environment
# (production, development, test). The code here should be idempotent so that it can be executed at any
# point in every environment. The data can then be loaded with the bin/rails db:seed command
# (or created alongside the database with db:setup).
#
# No seed data: GrupoMaterial, CorMaterial and Client are all managed through the app itself
# (Materiais page "+ Register new" dialogs, /clients) — there is nothing that must exist
# before the app can be used. Colors are capped to CorMaterial::COLOR_HEX's known names via
# the "Register New Color" dialog; groups and clients are freeform.
