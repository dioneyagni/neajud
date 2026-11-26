# Primeiros passos 2/6a (decided 20/11/2026 and 26/11/2026): the first-run
# wizard keeps, in the empresa, what the factory produces (tipos_produzidos;
# nil = not answered, everything on, as before the wizard), whose fabric it
# is, the step it stopped at ("Continuar de onde parei") and when it ended.
# Only new columns: nothing to transform.
class AdicionaAssistenteAEmpresa < ActiveRecord::Migration[8.1]
  def change
    add_column :empresas, :tipos_produzidos, :json
    add_column :empresas, :tecido_de, :string
    add_column :empresas, :assistente_passo, :string
    add_column :empresas, :assistente_concluido_em, :datetime
  end
end
