# An arte: the envelope of its files, one per part × size (Etapa 1.2, 2/3;
# decided 02/10/2026 — "uma arte por molde + referência + nome"). Each file is
# an Arquivo (versions, processing, preview and its tamanho stay per file);
# molde, client, referência and nome are the same in all of them
# (MembroDeArte keeps them in step).
#
# Usage: arquivo.arte.arquivos_por_parte # => { <Peca Lateral> => [<Arquivo 29-30>, …], nil => […] }
class Arte < ApplicationRecord
  include GeraUuid
  include Aprovavel
  include TipoDaArte

  has_many :arquivos, dependent: :restrict_with_error

  # Etapa 2.6a: blank = the dono's default (Parâmetros).
  validates :espacamento_mm, numericality: { greater_than_or_equal_to: 0, less_than: 1000 }, allow_nil: true
  # Etapa 2.6b1: its sizes' fit on the film follows its spacing and kind.
  after_update_commit -> { EncaixeDaEtiqueta.atualizar_arte!(self) }, if: -> { saved_change_to_espacamento_mm? || saved_change_to_tipo? }

  # The file that stands for the arte (gallery card): its first active one.
  # Usage: arte.principal.filename
  def principal
    arquivos.ativos.order(:id).first
  end

  # Active files by part (nil = part not known yet, last), each part with its
  # piloto first, then in size order — the corte's order when the size is
  # known, else the label. A work without corte has no corte to order by: its
  # sizes go by the file's measure, the smaller first (Etapa 2.6a, decided
  # 13/10/2026 — P, M, G whatever their names), the label breaking ties.
  # Usage: arte.arquivos_por_parte.each { |peca, arquivos| … }
  def arquivos_por_parte
    ativos = arquivos.ativos.includes(:peca, tamanho: { arquivo: :peca }, approved_version: :image_metadata).to_a
    ativos.group_by(&:resolved_peca)
          .sort_by { |peca, _| [ peca ? 0 : 1, peca&.nome.to_s ] }
          .to_h { |peca, lista| [ peca, lista.sort_by { |a| ordem_na_arte(a) } ] }
  end

  # The space between this etiqueta's copies on the DTF film: its own, else
  # the dono's default (Etapa 2.6a, decided 13/10/2026).
  # Usage: arte.espacamento_efetivo_mm # => 1.5
  def espacamento_efetivo_mm
    espacamento_mm || Empresa.atual&.espacamento_dtf_mm
  end

  # A new file of this arte, with its molde, client, referência and nome
  # (MembroDeArte::CAMPOS_DA_ARTE) — from the arte page or the upload.
  # Usage: arte.novo_arquivo(peca: lateral, tamanho_rotulo: "29-30")
  def novo_arquivo(**atributos)
    compartilhados = principal&.attributes&.slice(*MembroDeArte::CAMPOS_DA_ARTE)&.symbolize_keys || {}
    arquivos.build(**compartilhados, **atributos)
  end

  # The sizes a pedido asks this arte in, one by one (Etapa 1.2, 3/3;
  # decided 05/10/2026: "from the DXF"): the numbers its molde's organized
  # cortes serve; without any, the product's whole grade. The molde's
  # stretch doesn't enter. Empty without a molde — the pedido then takes a
  # single total. A DTF's are its own sizes, by measure (Etapa 2.6b1).
  # Usage: arte.tamanhos_do_pedido # => ["23", "24", …, "34"]
  def tamanhos_do_pedido
    return tamanhos_da_etiqueta if tipo == "dtf"

    molde = principal&.molde
    return [] unless molde

    numeros_dos_cortes(molde).presence || molde.modelo&.produto&.grade.to_a
  end

  # Every size a pedido may ask (decided 05/10/2026): the product's whole
  # grade, so "+ 23" / "+ 35" can add a number just outside the molde's
  # stretch (tamanhos_do_pedido, the ones listed first).
  # Usage: arte.grade_completa_do_pedido # => ["18", …, "46"]
  # Empty when nothing is listed (the pedido takes a single total then).
  def grade_completa_do_pedido
    listados = tamanhos_do_pedido
    return [] if listados.empty?

    completa = principal&.molde&.modelo&.produto&.grade.to_a
    (listados - completa).empty? ? completa : listados
  end

  # Each corte's numbers: saved with its grade type, else deduced from its
  # size names like the Mold Organization form ("24, 26…" → 23 … 34), else
  # the names themselves (old cortes nothing can be deduced from).
  def numeros_dos_cortes(molde)
    Arquivo.cortes_do_molde(molde).includes(:tamanhos).flat_map do |corte|
      tamanhos = corte.tamanhos.to_a
      next tamanhos.flat_map(&:numeros) if tamanhos.any? { |t| t.numeros.any? }

      deduzida = GradeDoCorte.deduzir(tamanhos.map(&:nome))
      deduzida ? deduzida[:tamanhos].flat_map { |t| t[:numeros] } : tamanhos.map(&:nome)
    end.uniq.sort_by { |n| [ n.to_i, n ] }
  end
  private :numeros_dos_cortes

  # A file's place in its part: piloto first, then the corte's size order
  # (calçado) or the measured area (a work without corte; without size/DPI
  # at the end), then the label.
  def ordem_na_arte(arquivo)
    medidas = !usa_pecas? && arquivo.approved_version&.medidas_mm
    posicao = medidas ? medidas.inject(:*) : arquivo.tamanho&.position || Float::INFINITY
    [ arquivo.piloto? ? 0 : 1, posicao, arquivo.rotulo_de_tamanho.to_s, arquivo.id ]
  end
  private :ordem_na_arte

  # A DTF's own grade (Etapa 2.6b1): its files' sizes, by measure. Empty for
  # a single unlabeled file — the pedido takes a single total then.
  def tamanhos_da_etiqueta
    arquivos_por_parte.values.flatten.filter_map(&:rotulo_de_tamanho).uniq
  end
  private :tamanhos_da_etiqueta

  # What the arte is called before its files say which part and size:
  # "001-TNS · 19 · BLUEY PTO", or the first file's name without a molde.
  # Usage: arte.titulo # => "001-TNS · 19 · BLUEY PTO"
  def titulo
    arquivo = principal
    return "" unless arquivo

    [ codigo, arquivo.molde&.codigo, arquivo.referencia&.nome, arquivo.nome ].compact_blank.join(" · ").presence || arquivo.filename
  end
end
