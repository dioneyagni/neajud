# An arte: the envelope of its files, one per part × size (Etapa 1.2, 2/3;
# decided 02/10/2026 — "uma arte por molde + referência + nome"). Each file is
# an Arquivo (versions, processing, preview and its tamanho stay per file);
# molde, client, referência and nome are the same in all of them
# (MembroDeArte keeps them in step).
#
# Usage: arquivo.arte.arquivos_por_parte # => { <Peca Lateral> => [<Arquivo 29-30>, …], nil => […] }
class Arte < ApplicationRecord
  include GeraUuid

  has_many :arquivos, dependent: :restrict_with_error

  # The file that stands for the arte (gallery card): its first active one.
  # Usage: arte.principal.filename
  def principal
    arquivos.ativos.order(:id).first
  end

  # Active files by part (nil = part not known yet, last), each part in size
  # order — the corte's order when the size is known, else the label.
  # Usage: arte.arquivos_por_parte.each { |peca, arquivos| … }
  def arquivos_por_parte
    ativos = arquivos.ativos.includes(:peca, :approved_version, tamanho: { arquivo: :peca }).to_a
    ativos.group_by(&:resolved_peca)
          .sort_by { |peca, _| [ peca ? 0 : 1, peca&.nome.to_s ] }
          .to_h { |peca, lista| [ peca, lista.sort_by { |a| [ a.tamanho&.position || 9999, a.rotulo_de_tamanho.to_s, a.id ] } ] }
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
