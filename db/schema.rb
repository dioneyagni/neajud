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

ActiveRecord::Schema[8.1].define(version: 2026_10_07_013357) do
  create_table "aprovacoes_arte", force: :cascade do |t|
    t.string "anexo_arquivo"
    t.string "anexo_nome"
    t.string "anexo_tipo"
    t.date "aprovado_em", null: false
    t.integer "arquivo_id", null: false
    t.integer "arquivo_version_id", null: false
    t.json "arquivo_version_ids", default: [], null: false
    t.integer "arte_id", null: false
    t.string "canal", null: false
    t.string "canal_detalhe"
    t.datetime "cancelada_em"
    t.integer "cancelada_por_id"
    t.datetime "created_at", null: false
    t.text "observacao"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.string "uuid", null: false
    t.index ["arquivo_id"], name: "index_aprovacoes_arte_on_arquivo_id"
    t.index ["arquivo_version_id"], name: "index_aprovacoes_arte_on_arquivo_version_id"
    t.index ["arte_id"], name: "index_aprovacoes_arte_on_arte_id"
    t.index ["user_id"], name: "index_aprovacoes_arte_on_user_id"
    t.index ["uuid"], name: "index_aprovacoes_arte_on_uuid", unique: true
  end

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

  create_table "arquivo_moldes", force: :cascade do |t|
    t.integer "arquivo_id", null: false
    t.datetime "created_at", null: false
    t.integer "molde_id", null: false
    t.datetime "updated_at", null: false
    t.index ["arquivo_id", "molde_id"], name: "index_arquivo_moldes_on_arquivo_id_and_molde_id", unique: true
    t.index ["arquivo_id"], name: "index_arquivo_moldes_on_arquivo_id"
    t.index ["molde_id"], name: "index_arquivo_moldes_on_molde_id"
  end

  create_table "arquivo_time_logs", force: :cascade do |t|
    t.integer "arquivo_id", null: false
    t.string "changed_by"
    t.datetime "created_at", null: false
    t.integer "new_seconds", null: false
    t.integer "previous_seconds", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.string "uuid", null: false
    t.index ["arquivo_id"], name: "index_arquivo_time_logs_on_arquivo_id"
    t.index ["user_id"], name: "index_arquivo_time_logs_on_user_id"
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

  create_table "arquivo_vinculo_logs", force: :cascade do |t|
    t.integer "arquivo_id", null: false
    t.string "changed_by"
    t.datetime "created_at", null: false
    t.integer "from_molde_id"
    t.string "from_molde_nome"
    t.integer "peca_id"
    t.integer "pedido_id"
    t.integer "to_molde_id"
    t.string "to_molde_nome", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.string "uuid", null: false
    t.index ["arquivo_id"], name: "index_arquivo_vinculo_logs_on_arquivo_id"
    t.index ["from_molde_id"], name: "index_arquivo_vinculo_logs_on_from_molde_id"
    t.index ["peca_id"], name: "index_arquivo_vinculo_logs_on_peca_id"
    t.index ["pedido_id"], name: "index_arquivo_vinculo_logs_on_pedido_id"
    t.index ["to_molde_id"], name: "index_arquivo_vinculo_logs_on_to_molde_id"
    t.index ["user_id"], name: "index_arquivo_vinculo_logs_on_user_id"
    t.index ["uuid"], name: "index_arquivo_vinculo_logs_on_uuid", unique: true
  end

  create_table "arquivos", force: :cascade do |t|
    t.integer "annotated_seconds"
    t.integer "approved_version_id"
    t.integer "arte_id"
    t.string "batch_id"
    t.datetime "buscando_tamanho_desde"
    t.string "category"
    t.text "category_notes"
    t.integer "client_id"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.integer "deleted_by_id"
    t.integer "estimated_seconds", default: 0
    t.string "extension", null: false
    t.string "filename", null: false
    t.string "mime_type", null: false
    t.integer "modelo_id"
    t.string "modelo_nome", default: "Novo Modelo"
    t.integer "molde_id"
    t.string "nome"
    t.string "organize_error"
    t.boolean "organized", default: false, null: false
    t.string "papel", default: "producao", null: false
    t.integer "peca_id"
    t.string "peca_nome", default: "Nova Peça"
    t.datetime "preparando_tamanhos_desde"
    t.integer "referencia_id"
    t.datetime "restored_at"
    t.integer "restored_by_id"
    t.integer "tamanho_id"
    t.string "tamanho_rotulo"
    t.string "tipo_corte"
    t.string "tipo_grade"
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.index ["approved_version_id"], name: "index_arquivos_on_approved_version_id"
    t.index ["arte_id"], name: "index_arquivos_on_arte_id"
    t.index ["client_id"], name: "index_arquivos_on_client_id"
    t.index ["deleted_at"], name: "index_arquivos_on_deleted_at"
    t.index ["modelo_id"], name: "index_arquivos_on_modelo_id"
    t.index ["molde_id"], name: "index_arquivos_on_molde_id"
    t.index ["peca_id"], name: "index_arquivos_on_peca_id"
    t.index ["referencia_id"], name: "index_arquivos_on_referencia_id"
    t.index ["tamanho_id"], name: "index_arquivos_on_tamanho_id"
    t.index ["tipo_corte"], name: "index_arquivos_on_tipo_corte"
    t.index ["uuid"], name: "index_arquivos_on_uuid", unique: true
  end

  create_table "artes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.index ["uuid"], name: "index_artes_on_uuid", unique: true
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

  create_table "clients", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.integer "deleted_by_id"
    t.text "name", null: false
    t.text "responsible", null: false
    t.datetime "restored_at"
    t.integer "restored_by_id"
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.index ["deleted_at"], name: "index_clients_on_deleted_at"
    t.index ["uuid"], name: "index_clients_on_uuid", unique: true
  end

  create_table "cor_materiais", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "nome", null: false
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.index ["nome"], name: "index_cor_materiais_on_nome", unique: true
    t.index ["uuid"], name: "index_cor_materiais_on_uuid", unique: true
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
    t.string "uuid", null: false
    t.decimal "width_mm", precision: 10, scale: 2
    t.index ["arquivo_version_id"], name: "index_cut_layers_on_arquivo_version_id"
    t.index ["uuid"], name: "index_cut_layers_on_uuid", unique: true
  end

  create_table "empresas", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "nome", null: false
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.index ["uuid"], name: "index_empresas_on_uuid", unique: true
  end

  create_table "exclusao_logs", force: :cascade do |t|
    t.string "acao", null: false
    t.string "changed_by"
    t.datetime "created_at", null: false
    t.integer "registro_id", null: false
    t.string "registro_rotulo", null: false
    t.string "registro_type", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.string "uuid", null: false
    t.index ["registro_type", "registro_id"], name: "index_exclusao_logs_on_registro"
    t.index ["user_id"], name: "index_exclusao_logs_on_user_id"
    t.index ["uuid"], name: "index_exclusao_logs_on_uuid", unique: true
  end

  create_table "funcoes", force: :cascade do |t|
    t.json "acoes", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.integer "deleted_by_id"
    t.boolean "dono", default: false, null: false
    t.json "niveis", default: {}, null: false
    t.string "nome", null: false
    t.datetime "restored_at"
    t.integer "restored_by_id"
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.index ["deleted_at"], name: "index_funcoes_on_deleted_at"
    t.index ["nome"], name: "index_funcoes_on_nome", unique: true
    t.index ["uuid"], name: "index_funcoes_on_uuid", unique: true
  end

  create_table "grupo_materiais", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "nome", null: false
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.index ["nome"], name: "index_grupo_materiais_on_nome", unique: true
    t.index ["uuid"], name: "index_grupo_materiais_on_uuid", unique: true
  end

  create_table "item_pedido_pecas", force: :cascade do |t|
    t.integer "arquivo_id"
    t.datetime "created_at", null: false
    t.boolean "incluida", default: true, null: false
    t.integer "item_pedido_id", null: false
    t.integer "peca_id"
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.index ["arquivo_id"], name: "index_item_pedido_pecas_on_arquivo_id"
    t.index ["item_pedido_id", "peca_id"], name: "index_item_pedido_pecas_on_item_pedido_id_and_peca_id", unique: true
    t.index ["item_pedido_id"], name: "index_item_pedido_pecas_on_item_pedido_id"
    t.index ["peca_id"], name: "index_item_pedido_pecas_on_peca_id"
    t.index ["uuid"], name: "index_item_pedido_pecas_on_uuid", unique: true
  end

  create_table "itens_pedido", force: :cascade do |t|
    t.integer "arquivo_id", null: false
    t.integer "arte_id"
    t.datetime "created_at", null: false
    t.integer "materia_prima_id"
    t.integer "pedido_id", null: false
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.index ["arquivo_id"], name: "index_itens_pedido_on_arquivo_id"
    t.index ["arte_id"], name: "index_itens_pedido_on_arte_id"
    t.index ["materia_prima_id"], name: "index_itens_pedido_on_materia_prima_id"
    t.index ["pedido_id"], name: "index_itens_pedido_on_pedido_id"
    t.index ["uuid"], name: "index_itens_pedido_on_uuid", unique: true
  end

  create_table "itens_pedido_grade", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "item_pedido_id", null: false
    t.integer "quantidade", default: 0, null: false
    t.string "tamanho_nome", null: false
    t.datetime "updated_at", null: false
    t.index ["item_pedido_id", "tamanho_nome"], name: "idx_grade_on_item_and_tamanho", unique: true
    t.index ["item_pedido_id"], name: "index_itens_pedido_grade_on_item_pedido_id"
  end

  create_table "materia_primas", force: :cascade do |t|
    t.integer "cor_material_id", null: false
    t.datetime "created_at", null: false
    t.string "gramatura", null: false
    t.integer "grupo_material_id", null: false
    t.string "largura", null: false
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.index ["cor_material_id"], name: "index_materia_primas_on_cor_material_id"
    t.index ["grupo_material_id", "cor_material_id", "largura", "gramatura"], name: "idx_materia_primas_composite", unique: true
    t.index ["grupo_material_id"], name: "index_materia_primas_on_grupo_material_id"
    t.index ["uuid"], name: "index_materia_primas_on_uuid", unique: true
  end

  create_table "modelos", force: :cascade do |t|
    t.string "abreviacao"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.integer "deleted_by_id"
    t.string "nome", null: false
    t.integer "produto_id"
    t.datetime "restored_at"
    t.integer "restored_by_id"
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.index ["abreviacao"], name: "index_modelos_on_abreviacao", unique: true
    t.index ["deleted_at"], name: "index_modelos_on_deleted_at"
    t.index ["nome"], name: "index_modelos_on_nome", unique: true
    t.index ["produto_id"], name: "index_modelos_on_produto_id"
    t.index ["uuid"], name: "index_modelos_on_uuid", unique: true
  end

  create_table "molde_pecas", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "espelhada", default: false, null: false
    t.integer "molde_id", null: false
    t.boolean "needs_cut", default: true, null: false
    t.integer "peca_id", null: false
    t.integer "pecas_por_par", default: 2, null: false
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.index ["molde_id", "peca_id"], name: "index_molde_pecas_on_molde_id_and_peca_id", unique: true
    t.index ["molde_id"], name: "index_molde_pecas_on_molde_id"
    t.index ["peca_id"], name: "index_molde_pecas_on_peca_id"
    t.index ["uuid"], name: "index_molde_pecas_on_uuid", unique: true
  end

  create_table "moldes", force: :cascade do |t|
    t.integer "base_id"
    t.integer "client_id", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.integer "deleted_by_id"
    t.integer "modelo_id"
    t.string "nome", null: false
    t.integer "numero", null: false
    t.datetime "published_at"
    t.datetime "restored_at"
    t.integer "restored_by_id"
    t.string "sufixo"
    t.string "tamanho_final"
    t.string "tamanho_inicial"
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.integer "variacao_de_id"
    t.integer "version", default: 1, null: false
    t.index ["base_id"], name: "index_moldes_on_base_id"
    t.index ["client_id", "numero"], name: "index_moldes_on_client_id_and_numero", unique: true
    t.index ["client_id"], name: "index_moldes_on_client_id"
    t.index ["deleted_at"], name: "index_moldes_on_deleted_at"
    t.index ["modelo_id"], name: "index_moldes_on_modelo_id"
    t.index ["uuid"], name: "index_moldes_on_uuid", unique: true
    t.index ["variacao_de_id"], name: "index_moldes_on_variacao_de_id"
  end

  create_table "movimento_estoques", force: :cascade do |t|
    t.integer "client_id", null: false
    t.datetime "created_at", null: false
    t.integer "materia_prima_id", null: false
    t.decimal "quantidade", default: "0.0", null: false
    t.string "tipo", null: false
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.decimal "valor", precision: 10, scale: 2
    t.index ["client_id"], name: "index_movimento_estoques_on_client_id"
    t.index ["created_at"], name: "index_movimento_estoques_on_created_at"
    t.index ["materia_prima_id"], name: "index_movimento_estoques_on_materia_prima_id"
    t.index ["uuid"], name: "index_movimento_estoques_on_uuid", unique: true
  end

  create_table "pecas", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.integer "deleted_by_id"
    t.string "nome", null: false
    t.datetime "restored_at"
    t.integer "restored_by_id"
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.index ["deleted_at"], name: "index_pecas_on_deleted_at"
    t.index ["nome"], name: "index_pecas_on_nome", unique: true
    t.index ["uuid"], name: "index_pecas_on_uuid", unique: true
  end

  create_table "pedidos", force: :cascade do |t|
    t.integer "client_id"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.integer "deleted_by_id"
    t.boolean "grade_antiga", default: false, null: false
    t.text "observacoes"
    t.datetime "restored_at"
    t.integer "restored_by_id"
    t.string "status", default: "rascunho", null: false
    t.string "tipo", default: "calcado", null: false
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.index ["client_id"], name: "index_pedidos_on_client_id"
    t.index ["deleted_at"], name: "index_pedidos_on_deleted_at"
    t.index ["status"], name: "index_pedidos_on_status"
    t.index ["uuid"], name: "index_pedidos_on_uuid", unique: true
  end

  create_table "produtos", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.integer "deleted_by_id"
    t.json "grade", default: [], null: false
    t.string "nome", null: false
    t.datetime "restored_at"
    t.integer "restored_by_id"
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.index ["deleted_at"], name: "index_produtos_on_deleted_at"
    t.index ["nome"], name: "index_produtos_on_nome", unique: true
    t.index ["uuid"], name: "index_produtos_on_uuid", unique: true
  end

  create_table "referencias", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "molde_id", null: false
    t.string "nome", null: false
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.index ["molde_id"], name: "index_referencias_on_molde_id"
    t.index ["uuid"], name: "index_referencias_on_uuid", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "solicitacoes_aprovacao", force: :cascade do |t|
    t.integer "arquivo_id", null: false
    t.integer "arquivo_version_id", null: false
    t.json "arquivo_version_ids", default: [], null: false
    t.integer "arte_id", null: false
    t.datetime "cancelada_em"
    t.integer "cancelada_por_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.string "uuid", null: false
    t.index ["arquivo_id"], name: "index_solicitacoes_aprovacao_on_arquivo_id"
    t.index ["arquivo_version_id"], name: "index_solicitacoes_aprovacao_on_arquivo_version_id"
    t.index ["arte_id"], name: "index_solicitacoes_aprovacao_on_arte_id"
    t.index ["user_id"], name: "index_solicitacoes_aprovacao_on_user_id"
    t.index ["uuid"], name: "index_solicitacoes_aprovacao_on_uuid", unique: true
  end

  create_table "tamanhos", force: :cascade do |t|
    t.decimal "area_mm2", precision: 10, scale: 2
    t.integer "arquivo_id", null: false
    t.datetime "created_at", null: false
    t.decimal "height_mm", precision: 10, scale: 2
    t.decimal "inner_lines_mm"
    t.string "nome", null: false
    t.json "numeros", default: [], null: false
    t.decimal "perimeter_mm"
    t.integer "position"
    t.string "preview_file"
    t.decimal "total_line_mm"
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.decimal "width_mm", precision: 10, scale: 2
    t.index ["arquivo_id"], name: "index_tamanhos_on_arquivo_id"
    t.index ["uuid"], name: "index_tamanhos_on_uuid", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "cloud_user_uuid"
    t.datetime "created_at", null: false
    t.datetime "desativado_em"
    t.integer "desativado_por_id"
    t.string "email_address", null: false
    t.string "nome", null: false
    t.string "password_digest", null: false
    t.boolean "trocar_senha", default: false, null: false
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.index ["cloud_user_uuid"], name: "index_users_on_cloud_user_uuid", unique: true
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["uuid"], name: "index_users_on_uuid", unique: true
  end

  create_table "vinculos", force: :cascade do |t|
    t.json "acessos_extras", default: {}, null: false
    t.datetime "created_at", null: false
    t.integer "empresa_id", null: false
    t.integer "funcao_id"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.string "uuid", null: false
    t.index ["empresa_id"], name: "index_vinculos_on_empresa_id"
    t.index ["funcao_id"], name: "index_vinculos_on_funcao_id"
    t.index ["user_id", "empresa_id"], name: "index_vinculos_on_user_id_and_empresa_id", unique: true
    t.index ["user_id"], name: "index_vinculos_on_user_id"
    t.index ["uuid"], name: "index_vinculos_on_uuid", unique: true
  end

  add_foreign_key "aprovacoes_arte", "arquivo_versions"
  add_foreign_key "aprovacoes_arte", "arquivos"
  add_foreign_key "aprovacoes_arte", "artes"
  add_foreign_key "aprovacoes_arte", "users"
  add_foreign_key "arquivo_image_metadata", "arquivo_versions"
  add_foreign_key "arquivo_moldes", "arquivos"
  add_foreign_key "arquivo_moldes", "moldes"
  add_foreign_key "arquivo_time_logs", "arquivos"
  add_foreign_key "arquivo_time_logs", "users"
  add_foreign_key "arquivo_versions", "arquivos"
  add_foreign_key "arquivo_vinculo_logs", "arquivos"
  add_foreign_key "arquivo_vinculo_logs", "moldes", column: "from_molde_id"
  add_foreign_key "arquivo_vinculo_logs", "moldes", column: "to_molde_id"
  add_foreign_key "arquivo_vinculo_logs", "pecas"
  add_foreign_key "arquivo_vinculo_logs", "pedidos"
  add_foreign_key "arquivo_vinculo_logs", "users"
  add_foreign_key "arquivos", "arquivo_versions", column: "approved_version_id"
  add_foreign_key "arquivos", "artes"
  add_foreign_key "arquivos", "clients"
  add_foreign_key "arquivos", "modelos"
  add_foreign_key "arquivos", "moldes"
  add_foreign_key "arquivos", "pecas"
  add_foreign_key "arquivos", "referencias"
  add_foreign_key "arquivos", "tamanhos"
  add_foreign_key "cut_layers", "arquivo_versions"
  add_foreign_key "exclusao_logs", "users"
  add_foreign_key "item_pedido_pecas", "arquivos"
  add_foreign_key "item_pedido_pecas", "itens_pedido", column: "item_pedido_id"
  add_foreign_key "item_pedido_pecas", "pecas"
  add_foreign_key "itens_pedido", "arquivos"
  add_foreign_key "itens_pedido", "artes"
  add_foreign_key "itens_pedido", "materia_primas"
  add_foreign_key "itens_pedido", "pedidos"
  add_foreign_key "itens_pedido_grade", "itens_pedido", column: "item_pedido_id"
  add_foreign_key "materia_primas", "cor_materiais"
  add_foreign_key "materia_primas", "grupo_materiais"
  add_foreign_key "modelos", "produtos"
  add_foreign_key "molde_pecas", "moldes"
  add_foreign_key "molde_pecas", "pecas"
  add_foreign_key "moldes", "clients"
  add_foreign_key "moldes", "modelos"
  add_foreign_key "moldes", "moldes", column: "base_id"
  add_foreign_key "moldes", "moldes", column: "variacao_de_id"
  add_foreign_key "movimento_estoques", "clients"
  add_foreign_key "movimento_estoques", "materia_primas"
  add_foreign_key "pedidos", "clients"
  add_foreign_key "referencias", "moldes"
  add_foreign_key "sessions", "users"
  add_foreign_key "solicitacoes_aprovacao", "arquivo_versions"
  add_foreign_key "solicitacoes_aprovacao", "arquivos"
  add_foreign_key "solicitacoes_aprovacao", "artes"
  add_foreign_key "solicitacoes_aprovacao", "users"
  add_foreign_key "tamanhos", "arquivos"
  add_foreign_key "vinculos", "empresas"
  add_foreign_key "vinculos", "funcoes"
  add_foreign_key "vinculos", "users"
end
