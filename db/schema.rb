# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_03_150000) do
  create_table "arquivo_image_metadata", force: :cascade do |t|
    t.integer "arquivo_version_id", null: false
    t.string "colorspace"
    t.string "colorspace_error"
    t.datetime "created_at", null: false
    t.float "dpi"
    t.boolean "has_spots", default: false
    t.integer "height_px"
    t.string "icc_profile"
    t.json "metadata"
    t.datetime "updated_at", null: false
    t.integer "width_px"
    t.index ["arquivo_version_id"], name: "idx_stamp_image_metadata_on_version", unique: true
    t.index ["arquivo_version_id"], name: "index_arquivo_image_metadata_on_arquivo_version_id"
  end

  create_table "arquivo_modelos", force: :cascade do |t|
    t.integer "arquivo_id", null: false
    t.datetime "created_at", null: false
    t.integer "modelo_id", null: false
    t.datetime "updated_at", null: false
    t.index ["arquivo_id", "modelo_id"], name: "index_arquivo_modelos_on_arquivo_id_and_modelo_id", unique: true
    t.index ["arquivo_id"], name: "index_arquivo_modelos_on_arquivo_id"
    t.index ["modelo_id"], name: "index_arquivo_modelos_on_modelo_id"
  end

  create_table "arquivo_time_logs", force: :cascade do |t|
    t.integer "arquivo_id", null: false
    t.string "changed_by"
    t.datetime "created_at", null: false
    t.integer "new_seconds", null: false
    t.integer "previous_seconds", null: false
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.index ["arquivo_id"], name: "index_arquivo_time_logs_on_arquivo_id"
    t.index ["uuid"], name: "index_arquivo_time_logs_on_uuid", unique: true
  end

  create_table "arquivo_versions", force: :cascade do |t|
    t.boolean "approved", default: false, null: false
    t.integer "arquivo_id", null: false
    t.string "category"
    t.text "category_notes"
    t.datetime "created_at", null: false
    t.string "extension", null: false
    t.string "filename", null: false
    t.string "mime_type", null: false
    t.string "original_file", null: false
    t.string "preview_file"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.integer "version_number", null: false
    t.index ["arquivo_id", "version_number"], name: "index_arquivo_versions_on_arquivo_id_and_version_number", unique: true
    t.index ["arquivo_id"], name: "index_arquivo_versions_on_arquivo_id"
    t.index ["uuid"], name: "index_arquivo_versions_on_uuid", unique: true
  end

  create_table "arquivos", force: :cascade do |t|
    t.integer "annotated_seconds"
    t.integer "approved_version_id"
    t.string "batch_id"
    t.string "category"
    t.text "category_notes"
    t.integer "client_id"
    t.datetime "created_at", null: false
    t.integer "estimated_seconds", default: 0
    t.string "extension", null: false
    t.string "filename", null: false
    t.string "mime_type", null: false
    t.integer "modelo_id"
    t.integer "molde_id"
    t.string "molde_nome", default: "Novo Molde"
    t.string "organize_error"
    t.boolean "organized", default: false, null: false
    t.integer "peca_id"
    t.string "peca_nome", default: "Nova Peça"
    t.integer "tamanho_id"
    t.string "tipo_corte"
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.index ["approved_version_id"], name: "index_arquivos_on_approved_version_id"
    t.index ["client_id"], name: "index_arquivos_on_client_id"
    t.index ["modelo_id"], name: "index_arquivos_on_modelo_id"
    t.index ["molde_id"], name: "index_arquivos_on_molde_id"
    t.index ["peca_id"], name: "index_arquivos_on_peca_id"
    t.index ["tamanho_id"], name: "index_arquivos_on_tamanho_id"
    t.index ["tipo_corte"], name: "index_arquivos_on_tipo_corte"
    t.index ["uuid"], name: "index_arquivos_on_uuid", unique: true
  end

  create_table "arte_cortes", force: :cascade do |t|
    t.integer "arte_id", null: false
    t.integer "corte_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["arte_id"], name: "index_arte_cortes_on_arte_id"
    t.index ["corte_id", "arte_id"], name: "index_arte_cortes_on_corte_id_and_arte_id", unique: true
    t.index ["corte_id"], name: "index_arte_cortes_on_corte_id"
  end

  create_table "bans", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.string "ip_address", null: false
    t.string "reason"
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.index ["ip_address"], name: "index_bans_on_ip_address"
    t.index ["uuid"], name: "index_bans_on_uuid", unique: true
  end

  create_table "batch_uploads", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "failed_files", default: 0
    t.integer "processed_files", default: 0
    t.integer "total_files", default: 0
    t.datetime "updated_at", null: false
    t.string "uploaded_by"
    t.string "uuid", null: false
    t.index ["uuid"], name: "index_batch_uploads_on_uuid", unique: true
  end

  create_table "clients", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "name", null: false
    t.text "responsible", null: false
    t.datetime "updated_at", null: false
  end

  create_table "cor_materiais", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "nome", null: false
    t.datetime "updated_at", null: false
    t.index ["nome"], name: "index_cor_materiais_on_nome", unique: true
  end

  create_table "cut_layers", force: :cascade do |t|
    t.string "annotation", default: "cut"
    t.decimal "area_mm2", precision: 10, scale: 2
    t.integer "arquivo_version_id", null: false
    t.string "color", null: false
    t.datetime "created_at", null: false
    t.decimal "height_mm", precision: 10, scale: 2
    t.string "layer_name", null: false
    t.decimal "perimeter_mm", precision: 10, scale: 2
    t.integer "position"
    t.datetime "updated_at", null: false
    t.decimal "width_mm", precision: 10, scale: 2
    t.index ["arquivo_version_id"], name: "index_cut_layers_on_arquivo_version_id"
  end

  create_table "grupo_materiais", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "nome", null: false
    t.datetime "updated_at", null: false
    t.index ["nome"], name: "index_grupo_materiais_on_nome", unique: true
  end

  create_table "materia_primas", force: :cascade do |t|
    t.integer "cor_material_id", null: false
    t.datetime "created_at", null: false
    t.string "gramatura", null: false
    t.integer "grupo_material_id", null: false
    t.string "largura", null: false
    t.datetime "updated_at", null: false
    t.index ["cor_material_id"], name: "index_materia_primas_on_cor_material_id"
    t.index ["grupo_material_id", "cor_material_id", "largura", "gramatura"], name: "idx_materia_primas_composite", unique: true
    t.index ["grupo_material_id"], name: "index_materia_primas_on_grupo_material_id"
  end

  create_table "modelos", force: :cascade do |t|
    t.integer "client_id", null: false
    t.datetime "created_at", null: false
    t.integer "molde_id"
    t.string "nome", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_modelos_on_client_id"
    t.index ["molde_id"], name: "index_modelos_on_molde_id"
    t.index ["nome", "client_id"], name: "index_modelos_on_nome_and_client_id", unique: true
  end

  create_table "molde_pecas", id: false, force: :cascade do |t|
    t.integer "molde_id", null: false
    t.integer "peca_id", null: false
    t.index ["molde_id", "peca_id"], name: "index_molde_pecas_on_molde_id_and_peca_id", unique: true
    t.index ["molde_id"], name: "index_molde_pecas_on_molde_id"
    t.index ["peca_id"], name: "index_molde_pecas_on_peca_id"
  end

  create_table "moldes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "nome", null: false
    t.datetime "updated_at", null: false
    t.index ["nome"], name: "index_moldes_on_nome", unique: true
  end

  create_table "movimento_estoques", force: :cascade do |t|
    t.integer "client_id", null: false
    t.datetime "created_at", null: false
    t.integer "materia_prima_id", null: false
    t.decimal "quantidade", default: "0.0", null: false
    t.string "tipo", null: false
    t.datetime "updated_at", null: false
    t.decimal "valor", precision: 10, scale: 2
    t.index ["client_id"], name: "index_movimento_estoques_on_client_id"
    t.index ["created_at"], name: "index_movimento_estoques_on_created_at"
    t.index ["materia_prima_id"], name: "index_movimento_estoques_on_materia_prima_id"
  end

  create_table "pecas", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "nome", null: false
    t.datetime "updated_at", null: false
    t.index ["nome"], name: "index_pecas_on_nome", unique: true
  end

  create_table "tamanhos", force: :cascade do |t|
    t.decimal "area_mm2", precision: 10, scale: 2
    t.integer "arquivo_id", null: false
    t.datetime "created_at", null: false
    t.decimal "height_mm", precision: 10, scale: 2
    t.decimal "inner_lines_mm"
    t.string "nome", null: false
    t.decimal "perimeter_mm"
    t.integer "position"
    t.string "preview_file"
    t.decimal "total_line_mm"
    t.datetime "updated_at", null: false
    t.decimal "width_mm", precision: 10, scale: 2
    t.index ["arquivo_id"], name: "index_tamanhos_on_arquivo_id"
  end

  add_foreign_key "arquivo_image_metadata", "arquivo_versions"
  add_foreign_key "arquivo_modelos", "arquivos"
  add_foreign_key "arquivo_modelos", "modelos"
  add_foreign_key "arquivo_time_logs", "arquivos"
  add_foreign_key "arquivo_versions", "arquivos"
  add_foreign_key "arquivos", "arquivo_versions", column: "approved_version_id"
  add_foreign_key "arquivos", "clients"
  add_foreign_key "arquivos", "modelos"
  add_foreign_key "arquivos", "moldes"
  add_foreign_key "arquivos", "pecas"
  add_foreign_key "arquivos", "tamanhos"
  add_foreign_key "arte_cortes", "arquivos", column: "arte_id"
  add_foreign_key "arte_cortes", "arquivos", column: "corte_id"
  add_foreign_key "cut_layers", "arquivo_versions"
  add_foreign_key "materia_primas", "cor_materiais"
  add_foreign_key "materia_primas", "grupo_materiais"
  add_foreign_key "modelos", "clients"
  add_foreign_key "modelos", "moldes"
  add_foreign_key "molde_pecas", "moldes"
  add_foreign_key "molde_pecas", "pecas"
  add_foreign_key "movimento_estoques", "clients"
  add_foreign_key "movimento_estoques", "materia_primas"
  add_foreign_key "tamanhos", "arquivos"
end
