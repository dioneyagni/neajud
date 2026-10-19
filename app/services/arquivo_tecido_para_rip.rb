# What the RIP gets for one tecido line (Etapa 2.7c, decided 19/10/2026):
# the item's file — the copy compacted at upload (ArquivoCompactadoTecido),
# else the original — named with the meters and the width to print, so the
# operator repeats the module that far: "CR-12_FLORAL_12,5m_1400mm.tif".
#
# Usage: rip = ArquivoTecidoParaRip.new(linha) # a LinhasDeProducao::Linha of the tecido
#        rip.estado  # => :pronto / :preparando
#        rip.caminho # => the file to send; nil while preparing
#        rip.nome    # => "CR-12_FLORAL_12,5m_1400mm.tif"
class ArquivoTecidoParaRip
  def initialize(linha)
    @item = linha.item
    @version = linha.arquivo.approved_version
  end

  delegate :estado, to: :compactado

  def caminho
    compactado.para_o_rip
  end

  def nome
    base = @item.arquivo.nome_completo(para_arquivo: true).presence || File.basename(@version.original_file, ".*")
    metros = format("%g", @item.metros.to_f).tr(".", ",")
    "#{base}_#{metros}m_#{@item.largura_efetiva_mm.to_i}mm#{File.extname(@version.original_file).downcase}"
  end

  # Queues the compacted copy when it is missing (uploaded before 2.7c, or a
  # job lost).
  def preparar!
    compactado.preparar!
  end

  private

  def compactado
    @compactado ||= ArquivoCompactadoTecido.new(@version)
  end
end
