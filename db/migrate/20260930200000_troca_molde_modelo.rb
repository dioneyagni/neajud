# Etapa 1.1 (2/5): the plan's names cross the code's (docs/plano.md,
# glossary): the old `moldes` (a style category: Jogging, Tenis) become
# `modelos`, and the old `modelos` (a client's form: 001-TNS) become
# `moldes`. Tables, columns and the polymorphic type stored in exclusao_logs
# swap through intermediate names. Swapping twice is the identity, so down
# runs the same steps. No behavior change: the specs, renamed, still pass.
class TrocaMoldeModelo < ActiveRecord::Migration[8.1]
  def up
    trocar!
  end

  def down
    trocar!
  end

  private

  def trocar!
    trocar_tabelas(:moldes, :modelos)
    trocar_tabelas(:molde_pecas, :modelo_pecas)
    # After the swap each table still carries the other's foreign key name.
    ajustar_chave(:molde_pecas, de: :modelo_id, para: :molde_id)
    ajustar_chave(:modelo_pecas, de: :molde_id, para: :modelo_id)
    ajustar_chave_da_forma
    trocar_colunas(:arquivos, :molde_id, :modelo_id)
    trocar_nome_padrao
    trocar_tabela_de_ligacao
    trocar_colunas_dos_logs
    trocar_tipo_polimorfico
  end

  def trocar_tabelas(a, b)
    rename_table a, :"#{a}_troca"
    rename_table b, a
    rename_table :"#{a}_troca", b
  end

  def ajustar_chave(tabela, de:, para:)
    rename_column tabela, de, para if column_exists?(tabela, de)
  end

  # The client's form (the table with client_id) points at its category with
  # the other table's name: moldes.modelo_id going up, modelos.molde_id down.
  def ajustar_chave_da_forma
    forma = column_exists?(:moldes, :client_id) ? :moldes : :modelos
    categoria_fk = forma == :moldes ? :modelo_id : :molde_id
    antiga = categoria_fk == :modelo_id ? :molde_id : :modelo_id
    rename_column forma, antiga, categoria_fk
  end

  def trocar_colunas(tabela, a, b)
    rename_column tabela, a, :"#{a}_troca"
    rename_column tabela, b, a
    rename_column tabela, :"#{a}_troca", b
  end

  # arquivos.molde_nome held the category name typed while organizing a DXF.
  def trocar_nome_padrao
    if column_exists?(:arquivos, :molde_nome)
      rename_column :arquivos, :molde_nome, :modelo_nome
      change_column_default :arquivos, :modelo_nome, from: "Novo Molde", to: "Novo Modelo"
    else
      rename_column :arquivos, :modelo_nome, :molde_nome
      change_column_default :arquivos, :molde_nome, from: "Novo Modelo", to: "Novo Molde"
    end
  end

  # A corte serves several client forms: arquivo_modelos <-> arquivo_moldes.
  def trocar_tabela_de_ligacao
    if table_exists?(:arquivo_modelos)
      rename_table :arquivo_modelos, :arquivo_moldes
      rename_column :arquivo_moldes, :modelo_id, :molde_id
    else
      rename_table :arquivo_moldes, :arquivo_modelos
      rename_column :arquivo_modelos, :molde_id, :modelo_id
    end
  end

  # An arte linked to a client form from a pedido: from/to the form.
  def trocar_colunas_dos_logs
    antigo, novo = column_exists?(:arquivo_vinculo_logs, :from_modelo_id) ? %w[modelo molde] : %w[molde modelo]
    %w[from to].each do |lado|
      rename_column :arquivo_vinculo_logs, :"#{lado}_#{antigo}_id", :"#{lado}_#{novo}_id"
      rename_column :arquivo_vinculo_logs, :"#{lado}_#{antigo}_nome", :"#{lado}_#{novo}_nome"
    end
  end

  def trocar_tipo_polimorfico
    execute <<~SQL
      UPDATE exclusao_logs SET registro_type = CASE registro_type
        WHEN 'Molde' THEN 'Modelo' WHEN 'Modelo' THEN 'Molde' END
      WHERE registro_type IN ('Molde', 'Modelo')
    SQL
  end
end
