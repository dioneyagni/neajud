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

  has_many :arquivos, dependent: :restrict_with_error

  # The file that stands for the arte (gallery card): its first active one.
  # Usage: arte.principal.filename
  def principal
    arquivos.ativos.order(:id).first
  end

  # Active files by part (nil = part not known yet, last), each part with its
  # piloto first, then in size order — the corte's order when the size is
  # known, else the label.
  # Usage: arte.arquivos_por_parte.each { |peca, arquivos| … }
  def arquivos_por_parte
    ativos = arquivos.ativos.includes(:peca, :approved_version, tamanho: { arquivo: :peca }).to_a
    ativos.group_by(&:resolved_peca)
          .sort_by { |peca, _| [ peca ? 0 : 1, peca&.nome.to_s ] }
          .to_h { |peca, lista| [ peca, lista.sort_by { |a| [ a.piloto? ? 0 : 1, a.tamanho&.position || 9999, a.rotulo_de_tamanho.to_s, a.id ] } ] }
  end

  # A new file of this arte, with its molde, client, referência and nome
  # (MembroDeArte::CAMPOS_DA_ARTE) — from the arte page or the upload.
  # Usage: arte.novo_arquivo(peca: lateral, tamanho_rotulo: "29-30")
  def novo_arquivo(**atributos)
    compartilhados = principal&.attributes&.slice(*MembroDeArte::CAMPOS_DA_ARTE)&.symbolize_keys || {}
    arquivos.build(**compartilhados, **atributos)
  end

  # The sizes a pedido asks this arte in, one by one (Etapa 1.2, 3/3): the
  # molde's stretch of the grade; without one, the numbers its cortes serve;
  # with cortes from before the grade type, their size names. Empty without
  # a molde — the pedido then takes a single total.
  # Usage: arte.tamanhos_do_pedido # => ["24", "25", …, "34"]
  def tamanhos_do_pedido
    molde = principal&.molde
    return [] unless molde
    return molde.grade if molde.grade.any?

    tamanhos = Tamanho.unscoped.where(arquivo_id: Arquivo.cortes_do_molde(molde).select(:id)).order(:position).to_a
    numeros = tamanhos.flat_map(&:numeros).uniq
    numeros.any? ? numeros.sort_by(&:to_i) : tamanhos.map(&:nome).uniq
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

  # What the arte is called before its files say which part and size:
  # "001-TNS · 19 · BLUEY PTO", or the first file's name without a molde.
  # Usage: arte.titulo # => "001-TNS · 19 · BLUEY PTO"
  def titulo
    arquivo = principal
    return "" unless arquivo

    [ arquivo.molde&.codigo, arquivo.referencia&.nome, arquivo.nome ].compact_blank.join(" · ").presence || arquivo.filename
  end
end
