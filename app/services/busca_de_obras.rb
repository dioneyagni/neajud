# The DTF and tecido pedido pages' search (Etapa 2.6b1, 2.7a): the works of
# the pedido's type — by file name or nome, by number ("863", "DTF-863",
# "CR-12"), and a cor lisa by its family ("Laranja"; "Laranja 3": the letters
# narrow the number to that family). The visible files are injected.
#
# Usage: BuscaDeObras.call(visiveis(Arquivo), "tecido", "laranja").map(&:arte)
class BuscaDeObras
  LIMITE = 40

  def self.call(arquivos, tipo_do_pedido, termo)
    obras = Arte.where(tipo: Pedido::TIPO_DA_ARTE.filter_map { |tipo_da_arte, tipo| tipo_da_arte if tipo == tipo_do_pedido })
    obras = buscar(obras, termo.to_s.strip) if termo.present?
    arquivos.ativos.where(category: "artes", arte: obras).principais_das_artes
            .includes(:arte, :client).order(id: :desc).limit(LIMITE)
  end

  def self.buscar(obras, termo)
    parecidos = Arquivo.where("arquivos.filename LIKE :t OR arquivos.nome LIKE :t", t: "%#{Arquivo.sanitize_sql_like(termo)}%").select(:arte_id)
    obras.where(id: parecidos).or(por_numero(obras, termo)).or(obras.where("artes.familia LIKE ?", "#{Arte.sanitize_sql_like(termo)}%"))
  end

  def self.por_numero(obras, termo)
    com_numero = obras.where(numero: termo[/\d+/])
    letras = termo[/\p{L}+/]
    return com_numero unless letras

    com_numero.where("artes.familia = '' OR artes.familia LIKE ?", "#{Arte.sanitize_sql_like(letras)}%")
  end
  private_class_method :buscar, :por_numero
end
