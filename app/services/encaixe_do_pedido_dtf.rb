# A DTF pedido's lines on the film (Etapa 2.6b1, decided 13/10/2026): one
# line per etiqueta × size, each in its own rows (D2). The size's stored fit
# (EncaixeDaEtiqueta) gives the copies per row both ways; the line goes
# standing, or turned when the team marked the etiqueta to turn (decided
# 16/10/2026: picking the one with fewer meters turned too many), completes
# the last row and adds its extra rows — its own, else the
# pedido's (D3). What is printed beyond the quantity goes to the client.
# A confirmed pedido reads the fit written at confirmation (gravar!), so a
# later version or film change never moves it.
#
# Usage: EncaixeDoPedidoDtf.call(pedido).sum(&:metros) # => 0.37
#        EncaixeDoPedidoDtf.call(pedido).first.impressas # => 32
class EncaixeDoPedidoDtf
  # pendencia: :sem_arquivo (no active file of that size), :sem_medida (the
  # file has no size or DPI), :nao_cabe (wider than the film both ways),
  # :nao_cabe_em_pe / :nao_cabe_girada (it fits only the other way than the
  # etiqueta's mark: the team marks or unmarks "turn").
  Linha = Struct.new(:item, :grade, :arquivo, :pedidas, :extras, :por_fileira, :passo_mm, :girada,
                     :fileiras, :impressas, :metros, :pendencia, keyword_init: true) do
    def excedente
      impressas.to_i - pedidas
    end

    # The fit written into the grade when the pedido is confirmed.
    def para_gravar
      { "por_fileira" => por_fileira, "passo_mm" => passo_mm, "girada" => girada, "extras" => extras,
        "fileiras" => fileiras, "impressas" => impressas, "metros" => metros }
    end
  end

  def self.call(pedido)
    new(pedido).call
  end

  # Writes each line's fit into its grade (confirming).
  # Usage: EncaixeDoPedidoDtf.gravar!(pedido)
  def self.gravar!(pedido)
    call(pedido).each { |linha| linha.grade.update!(encaixe_dtf: linha.para_gravar) unless linha.pendencia }
  end

  # The fit of a quantity on one orientation: [fileiras, impressas, metros].
  # Usage: EncaixeDoPedidoDtf.fileiras_de(100, { "por_fileira" => 32, "passo_mm" => 18.52 }, 1) # => [5, 160, 0.0926]
  def self.fileiras_de(pedidas, posicao, extras)
    fileiras = (pedidas.to_f / posicao["por_fileira"]).ceil + extras
    [ fileiras, fileiras * posicao["por_fileira"], (fileiras * posicao["passo_mm"] / 1000.0).round(4) ]
  end

  def initialize(pedido)
    @pedido = pedido
  end

  def call
    @pedido.itens_pedido.includes(:grades, arte: :arquivos).order(:id).flat_map do |item|
      ordem = item.arte.tamanhos_do_pedido
      grades = item.grades.select { |g| g.quantidade.positive? }.sort_by { |g| ordem.index(g.tamanho_nome) || ordem.size }
      grades.map { |grade| linha(item, grade) }
    end
  end

  private

  def linha(item, grade)
    arquivo = arquivo_do_tamanho(item, grade.tamanho_nome)
    base = { item: item, grade: grade, arquivo: arquivo, pedidas: grade.quantidade, extras: grade.fileiras_extras || @pedido.fileiras_extras }
    return Linha.new(**base, **gravada(grade.encaixe_dtf)) if grade.encaixe_dtf && !@pedido.confirmavel?

    pendencia = pendencia_de(arquivo, item.arte.orientacao_dtf)
    return Linha.new(**base, pendencia: pendencia) if pendencia

    Linha.new(**base, **na_orientacao(arquivo.encaixe_dtf, item.arte.orientacao_dtf, grade.quantidade, base[:extras]))
  end

  def gravada(encaixe)
    encaixe.slice("por_fileira", "passo_mm", "girada", "fileiras", "impressas", "metros").transform_keys(&:to_sym).merge(extras: encaixe["extras"])
  end

  # The fit in the etiqueta's orientation ("em_pe" / "girada").
  def na_orientacao(encaixe, orientacao, pedidas, extras)
    posicao = encaixe.fetch(orientacao)
    fileiras, impressas, metros = self.class.fileiras_de(pedidas, posicao, extras)
    { girada: orientacao == "girada", por_fileira: posicao["por_fileira"], passo_mm: posicao["passo_mm"],
      fileiras: fileiras, impressas: impressas, metros: metros }
  end

  def pendencia_de(arquivo, orientacao)
    return :sem_arquivo unless arquivo
    return :sem_medida unless arquivo.encaixe_dtf
    return :nao_cabe unless arquivo.encaixe_dtf["em_pe"] || arquivo.encaixe_dtf["girada"]
    return :"nao_cabe_#{orientacao}" unless arquivo.encaixe_dtf[orientacao]

    nil
  end

  # The size's active file; "_total" is a DTF with a single, unlabeled file.
  def arquivo_do_tamanho(item, tamanho_nome)
    ativos = item.arte.arquivos.reject(&:excluido?)
    return ativos.first if tamanho_nome == ProducaoPedidoService::TOTAL_KEY && ativos.one?

    ativos.find { |arquivo| arquivo.rotulo_de_tamanho == tamanho_nome }
  end
end
