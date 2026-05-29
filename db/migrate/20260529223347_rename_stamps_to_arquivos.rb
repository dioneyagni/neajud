class RenameStampsToArquivos < ActiveRecord::Migration[8.1]
  def up
    # ── Remove all FKs referencing stamp tables (before renaming) ──
    remove_foreign_key :stamp_image_metadata, :stamp_versions
    remove_foreign_key :stamp_versions, :stamps
    remove_foreign_key :stamp_time_logs, :stamps
    remove_foreign_key :tamanhos, :stamps
    remove_foreign_key :cut_layers, :stamp_versions
    remove_foreign_key :stamps, :stamp_versions, column: :approved_version_id
    remove_foreign_key :stamps, :clients
    remove_foreign_key :stamps, :modelos
    remove_foreign_key :stamps, :moldes
    remove_foreign_key :stamps, :pecas
    remove_foreign_key :stamps, :tamanhos

    # ── Tables ──
    rename_table :stamps, :arquivos
    rename_table :stamp_versions, :arquivo_versions
    rename_table :stamp_time_logs, :arquivo_time_logs
    rename_table :stamp_image_metadata, :arquivo_image_metadata

    # ── Columns ──
    rename_column :arquivo_versions, :stamp_id, :arquivo_id
    rename_column :arquivo_time_logs, :stamp_id, :arquivo_id
    rename_column :arquivo_image_metadata, :stamp_version_id, :arquivo_version_id
    rename_column :cut_layers, :stamp_version_id, :arquivo_version_id
    rename_column :tamanhos, :stamp_id, :arquivo_id

    # ── Foreign keys (new names) ──
    add_foreign_key :arquivo_versions, :arquivos
    add_foreign_key :arquivo_time_logs, :arquivos
    add_foreign_key :arquivo_image_metadata, :arquivo_versions
    add_foreign_key :tamanhos, :arquivos
    add_foreign_key :cut_layers, :arquivo_versions
    add_foreign_key :arquivos, :clients
    add_foreign_key :arquivos, :modelos
    add_foreign_key :arquivos, :moldes
    add_foreign_key :arquivos, :pecas
    add_foreign_key :arquivos, :tamanhos
    add_foreign_key :arquivos, :arquivo_versions, column: :approved_version_id
  end

  def down
    # Remove FKs with new names
    remove_foreign_key :arquivo_versions, :arquivos
    remove_foreign_key :arquivo_time_logs, :arquivos
    remove_foreign_key :arquivo_image_metadata, :arquivo_versions
    remove_foreign_key :tamanhos, :arquivos
    remove_foreign_key :cut_layers, :arquivo_versions
    remove_foreign_key :arquivos, :clients
    remove_foreign_key :arquivos, :modelos
    remove_foreign_key :arquivos, :moldes
    remove_foreign_key :arquivos, :pecas
    remove_foreign_key :arquivos, :tamanhos
    remove_foreign_key :arquivos, :arquivo_versions, column: :approved_version_id

    # Rename columns back
    rename_column :arquivo_versions, :arquivo_id, :stamp_id
    rename_column :arquivo_time_logs, :arquivo_id, :stamp_id
    rename_column :arquivo_image_metadata, :arquivo_version_id, :stamp_version_id
    rename_column :cut_layers, :arquivo_version_id, :stamp_version_id
    rename_column :tamanhos, :arquivo_id, :stamp_id

    # Rename tables back
    rename_table :arquivos, :stamps
    rename_table :arquivo_versions, :stamp_versions
    rename_table :arquivo_time_logs, :stamp_time_logs
    rename_table :arquivo_image_metadata, :stamp_image_metadata

    # Re-add FKs with old names
    add_foreign_key :stamp_image_metadata, :stamp_versions
    add_foreign_key :stamp_versions, :stamps
    add_foreign_key :stamp_time_logs, :stamps
    add_foreign_key :tamanhos, :stamps
    add_foreign_key :cut_layers, :stamp_versions
    add_foreign_key :stamps, :stamp_versions, column: :approved_version_id
    add_foreign_key :stamps, :clients
    add_foreign_key :stamps, :modelos
    add_foreign_key :stamps, :moldes
    add_foreign_key :stamps, :pecas
    add_foreign_key :stamps, :tamanhos
  end
end
