# Where each ordered number of a pedido item comes from (Etapa 1.2, 3/3 parte
# 2; docs/plano.md "Tamanhos e grade"): for each part of the arte and each
# number with quantity, the size of the part's DXF that serves it, and the
# arte's file for that size — the production one, or the part's piloto for a
# sample (an arte asked only in the piloto's size with no production file
# for it, decided 05/10/2026), or a pendência:
#   :sem_corte   — no organized DXF of the part serves the number;
#   :sem_arquivo — the DXF serves it, the arte has no file of that size;
#   :sem_lado    — a mirrored part (molde_pecas.espelhada) has a file with a
#                  side in that size but not the other side's (Etapa 1.2, 3/3
#                  parte 3c, decided 07/10/2026: a file without side serves
#                  both until one with a side arrives).
# The pedido always reads the arte: a file added to it settles the pendência
# in every draft that uses it.
#
# `colunas:` also gives each part the DXF size of numbers not ordered (yet):
# the pedido page's matrix shows every column of the grade (Etapa 1.2, 3/3
# parte 3a).
#
# Each part also carries its molde part's config — pieces per pair, mirrored,
# cut or not (Etapa 1.2, 3/3 parte 3b) — for Corte and Impressão.
#
# Usage: ResolucaoDoItem.call(item).each { |parte| parte.pendencias }
#        ResolucaoDoItem.call(item, colunas: %w[28 29 30]).first.celula("28")
class ResolucaoDoItem
  # lados: { "direito" => file, "esquerdo" => file } when the part is mirrored
  # and its files have sides; lado_faltando: the side :sem_lado misses.
  Numero = Struct.new(:numero, :quantidade, :tamanho, :arquivo, :origem, :pendencia, :lados, :lado_faltando, keyword_init: true)
  # A part with no molde part (an arte without molde): one piece per foot.
  CONFIG_PADRAO = { pecas_por_par: 2, espelhada: false, needs_cut: true }.freeze
  # arquivos: the arte's files of the part (its thumbnail when no number
  # resolved to one yet); tamanhos: number => DXF size, for the `colunas`.
  Parte = Struct.new(:peca_row, :peca, :incluida, :numeros, :arquivos, :tamanhos, :config, keyword_init: true) do
    def pendencias
      numeros.select(&:pendencia)
    end

    # The ordered number resolved, else just the DXF size that would serve it.
    # Usage: parte.celula("28") # => #<Numero numero="28" quantidade=0 tamanho=…>
    def celula(numero)
      numeros.find { |n| n.numero == numero } || Numero.new(numero: numero, quantidade: 0, tamanho: tamanhos[numero])
    end

    # The numbers by DXF size, in the part's order: [[tamanho, [Numero…]], …];
    # numbers no DXF serves come last (tamanho nil).
    def por_tamanho
      numeros.group_by(&:tamanho).sort_by { |tamanho, _| tamanho ? [ 0, tamanho.position.to_i ] : [ 1, 0 ] }
    end
  end

  def self.call(item, colunas: [])
    new(item, colunas).call
  end

  def initialize(item, colunas = [])
    @item = item
    @colunas = colunas
    @molde = item.arte&.principal&.molde
  end

  def call
    pedidos = @item.grades.select { |g| g.quantidade.positive? }.sort_by { |g| [ g.tamanho_nome.to_i, g.tamanho_nome ] }
    @item.item_pedido_pecas.map do |row|
      Parte.new(peca_row: row, peca: row.peca, incluida: row.incluida, arquivos: arquivos_da_parte(row.peca),
                numeros: pedidos.map { |grade| resolver(row.peca, grade, pedidos) },
                tamanhos: @colunas.to_h { |numero| [ numero, tamanho_do_corte(row.peca, numero) ] }, config: config_da_parte(row.peca))
    end
  end

  private

  def resolver(peca, grade, pedidos)
    return pelo_total(peca, grade) if grade.tamanho_nome == ProducaoPedidoService::TOTAL_KEY

    tamanho = tamanho_do_corte(peca, grade.tamanho_nome)
    base = { numero: grade.tamanho_nome, quantidade: grade.quantidade, tamanho: tamanho }
    return Numero.new(**base, pendencia: :sem_corte) unless tamanho

    producao = arquivos_da_parte(peca).reject(&:piloto?).select { |a| serve?(a, tamanho) }
    return por_lado(base, producao) if config_da_parte(peca)[:espelhada] && producao.any?(&:lado)
    return Numero.new(**base, arquivo: producao.first, origem: :producao) if producao.any?

    piloto = arquivos_da_parte(peca).find(&:piloto?)
    return Numero.new(**base, arquivo: piloto, origem: :piloto) if piloto && amostra?(peca, piloto, pedidos)

    Numero.new(**base, pendencia: :sem_arquivo)
  end

  # A mirrored part whose files have sides: one of each, else :sem_lado.
  def por_lado(base, producao)
    lados = LadoNaArte::LADOS.index_with { |lado| producao.find { |a| a.lado == lado } }
    faltando = lados.key(nil)
    arquivo = lados.values.compact.first
    return Numero.new(**base, arquivo: arquivo, lados: lados, origem: :producao) unless faltando

    Numero.new(**base, arquivo: arquivo, lados: lados, pendencia: :sem_lado, lado_faltando: faltando)
  end

  # The item's molde part: pieces per pair, mirrored, cut or not.
  def config_da_parte(peca)
    @configs ||= {}
    @configs[peca&.id] ||= begin
      parte = @molde && peca && @molde.molde_pecas.find_by(peca: peca)
      parte ? { pecas_por_par: parte.pecas_por_par, espelhada: parte.espelhada, needs_cut: parte.needs_cut } : CONFIG_PADRAO
    end
  end

  # The single total (an arte without molde, no grade by number): the size
  # chosen on the file itself, as before Etapa 1.2.
  def pelo_total(peca, grade)
    arquivo = arquivos_da_parte(peca).find(&:tamanho)
    base = { numero: grade.tamanho_nome, quantidade: grade.quantidade, tamanho: arquivo&.tamanho }
    arquivo ? Numero.new(**base, arquivo: arquivo, origem: :producao) : Numero.new(**base, pendencia: :sem_corte)
  end

  # A sample: every ordered number falls in one size of this part's DXF, the
  # one the piloto is in.
  def amostra?(peca, piloto, pedidos)
    tamanhos = pedidos.map { |grade| tamanho_do_corte(peca, grade.tamanho_nome) }.uniq
    tamanhos.size == 1 && tamanhos.first && serve?(piloto, tamanhos.first)
  end

  def serve?(arquivo, tamanho)
    return arquivo.tamanho_id == tamanho.id if arquivo.tamanho_id

    arquivo.tamanho_rotulo.present? && tamanho.atende_rotulo?(arquivo.tamanho_rotulo)
  end

  def tamanho_do_corte(peca, numero)
    (cortes_por_peca[peca&.id] || []).flat_map(&:tamanhos).find { |t| t.atende_rotulo?(numero) }
  end

  def cortes_por_peca
    @cortes_por_peca ||= @molde ? Arquivo.cortes_do_molde(@molde).includes(:tamanhos).order(:id).group_by(&:peca_id) : {}
  end

  def arquivos_da_parte(peca)
    @arquivos_por_peca ||= (@item.arte&.arquivos&.ativos&.includes(:peca, :approved_version, tamanho: { arquivo: :peca })&.order(:id).to_a || [])
                           .group_by { |a| a.resolved_peca&.id }
    @arquivos_por_peca[peca&.id] || []
  end
end
