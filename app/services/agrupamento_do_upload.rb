# Groups the files of one upload into artes before anything is sent (Etapa
# 1.2, 2/3 parte 3; docs/plano.md "Agrupamento no upload"). Files whose names
# have the same referência (leading number) and nome — without part, size,
# measure and copy leftovers, compared ignoring case and accents — are one
# arte. Cortes and names without a nome stay alone.
#
# Each file comes back with the part, size and side (DIR / ESQ, Etapa 1.2,
# 3/3 parte 3c) read from its name and whether
# it looks like its part's piloto: an editable format (PSD/AI/CDR), else
# 3 times or more the median weight of the other files of the part (decided
# 05/10/2026). Each group lists existing artes with the same referência and
# nome, to offer adding to them (never chosen for the user).
#
# Usage: AgrupamentoDoUpload.call([{ nome: "20-BLUEY-LATERAL-29_30.tif", bytes: 5_000_000 }, …])
#   # => { conferir: true, grupos: [Grupo(titulo: "20 · BLUEY", arquivos: [...], existentes: [...])] }
class AgrupamentoDoUpload
  EDITAVEIS = %w[psd ai cdr].freeze
  PESO_DO_PILOTO = 3

  ArquivoLido = Struct.new(:indice, :nome, :bytes, :parte, :tamanho, :lado, :piloto, keyword_init: true)
  Grupo = Struct.new(:chave, :referencia, :nome, :arquivos, :existentes, keyword_init: true) do
    def titulo
      [ referencia, nome ].compact.join(" · ")
    end
  end

  def self.call(arquivos, pecas: Peca.ativos.to_a)
    new(arquivos, pecas).call
  end

  def initialize(arquivos, pecas)
    @arquivos = arquivos
    @pecas = pecas.index_by(&:nome)
  end

  def call
    grupos = agrupar.map { |grupo| grupo.tap { sugerir_pilotos(grupo.arquivos) } }
    grupos.each { |grupo| grupo.existentes = existentes(grupo) if grupo.nome }
    { conferir: grupos.any? { |g| g.arquivos.size > 1 || g.arquivos.any?(&:piloto) }, grupos: grupos }
  end

  private

  def agrupar
    @arquivos.each_with_index.each_with_object({}) do |(entrada, indice), grupos|
      lido = NomeDoArquivo.ler(entrada[:nome], partes: @pecas.keys)
      chave = chave_de(entrada[:nome], lido, indice)
      grupo = grupos[chave] ||= novo_grupo(chave, lido)
      grupo.arquivos << ArquivoLido.new(indice: indice, nome: entrada[:nome], bytes: entrada[:bytes].to_i,
                                        parte: @pecas[lido[:parte]], tamanho: lido[:tamanho], lado: lido[:lado], piloto: false)
    end.values
  end

  def novo_grupo(chave, lido)
    sozinho = chave.first == :sozinho
    Grupo.new(chave: chave, referencia: lido[:referencia], nome: (lido[:nome] unless sozinho), arquivos: [], existentes: [])
  end

  # Alone (its own key) when it can't be grouped: a corte, or no nome left.
  def chave_de(nome, lido, indice)
    sozinho = lido[:nome].nil? || FileCategory.for_extension(extensao(nome)) != "artes"
    sozinho ? [ :sozinho, indice ] : [ lido[:referencia], TextoComparavel.chave(lido[:nome]) ]
  end

  def sugerir_pilotos(arquivos)
    arquivos.group_by(&:parte).each_value do |da_parte|
      piloto = editavel(da_parte) || muito_mais_pesado(da_parte)
      piloto.piloto = true if piloto
    end
  end

  def editavel(arquivos)
    arquivos.select { |a| EDITAVEIS.include?(extensao(a.nome)) }.max_by(&:bytes)
  end

  def muito_mais_pesado(arquivos)
    return nil if arquivos.size < 2

    maior = arquivos.max_by(&:bytes)
    outros = (arquivos - [ maior ]).map(&:bytes).sort
    maior if maior.bytes >= PESO_DO_PILOTO * outros[outros.size / 2]
  end

  # Existing artes (their first file) with this referência and nome: the
  # stored ones once a molde gave them, else read from the file name.
  def existentes(grupo)
    palavra = grupo.nome.split.first.to_s
    candidatas = Arquivo.ativos.where(category: "artes").principais_das_artes.includes(:referencia, :arte, molde: :modelo)
                        .where("arquivos.nome LIKE :p OR arquivos.filename LIKE :p", p: "%#{Arquivo.sanitize_sql_like(palavra)}%").limit(200)
    candidatas.select { |arquivo| chave_existente(arquivo) == grupo.chave }.first(5)
  end

  def chave_existente(arquivo)
    return [ arquivo.referencia&.nome, TextoComparavel.chave(arquivo.nome) ] if arquivo.nome.present?

    lido = NomeDoArquivo.ler(arquivo.filename, partes: @pecas.keys)
    [ lido[:referencia], lido[:nome] && TextoComparavel.chave(lido[:nome]) ]
  end

  def extensao(nome)
    File.extname(nome.to_s).delete(".").downcase
  end
end
