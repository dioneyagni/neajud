# The lines of a production stage, each with a stable key (Etapa 2.2, 2/3;
# decided 07/10/2026) — what a baixa covers and what a lock checks:
#   impressao lines (Impressão, Estamparia, Conferência): arte × part × size ×
#     side, key "<item>/<part>/<size>/<file>/<side>"; corte_chave points at the
#     Corte line it waits for (nil for a part "não corta");
#   corte lines: part × DXF size × material, key "<part>/<size>/<material>";
#   dtf lines (Etapa 2.6b2, D1): etiqueta × size, as on the pedido's table,
#     key "<item>/<size>/<file>"; expected the film's meters or the units
#     printed (excess included: it is printed and cut too);
#   tecido lines (Etapa 2.7c): the item (arte × fabric), key
#     "<item>/<file>"; expected the item's meters (paper and fabric alike).
# Keys are made of uuids (nothing integer leaves the server). Lines with a
# pendência (no file, no DXF) are left out: they can't be produced, and a
# confirmed pedido has none.
#
# Usage: LinhasDeProducao.call(pedido, EtapasProducao.etapa("calcado", "corte")).map(&:chave)
class LinhasDeProducao
  # dispensa: stages this line skips — a reposição's line not printed again
  # (Etapa 2.2, 4/4); its Estamparia doesn't wait for them.
  # encaixe: a DTF line's fit on the film (EncaixeDoPedidoDtf::Linha).
  Linha = Struct.new(:chave, :referencia, :item, :peca, :tamanho, :arquivo, :lado, :materia_prima,
                     :pecas, :esperado, :corte_chave, :origem, :dispensa, :encaixe, keyword_init: true)

  def self.call(pedido, etapa, largura_papel_mm: Empresa.atual&.largura_papel_efetiva_mm)
    new(pedido, etapa, largura_papel_mm).call
  end

  # The Corte line key of a part × size × material.
  # Usage: LinhasDeProducao.chave_do_corte(lateral, tamanho, material) # => "8f3a…/2b1c…/9d0e…"
  def self.chave_do_corte(peca, tamanho, materia_prima)
    [ peca&.uuid, tamanho&.uuid, materia_prima&.uuid ].join("/")
  end

  # The key of an Impressão line (also Estamparia's and Conferência's).
  # Usage: LinhasDeProducao.chave_da_impressao(item, linha) # => "<item>/<part>/<size>/<file>/<side>"
  def self.chave_da_impressao(item, linha)
    [ item.uuid, linha.peca&.uuid, linha.tamanho&.uuid, linha.arquivo&.uuid, linha.lado ].join("/")
  end

  # The key of a DTF line (Etapa 2.6b2), from its fit on the film.
  # Usage: LinhasDeProducao.chave_do_dtf(encaixe) # => "<item>/P/<file>"
  def self.chave_do_dtf(encaixe)
    [ encaixe.item.uuid, encaixe.grade.tamanho_nome, encaixe.arquivo.uuid ].join("/")
  end

  # The key of a tecido line (Etapa 2.7c): its item and file.
  # Usage: LinhasDeProducao.chave_do_tecido(item) # => "<item>/<file>"
  def self.chave_do_tecido(item)
    [ item.uuid, item.arquivo.uuid ].join("/")
  end

  def initialize(pedido, etapa, largura_papel_mm)
    @pedido = pedido
    @etapa = etapa
    @largura_papel_mm = largura_papel_mm
  end

  def call
    case @etapa.linhas
    when "corte" then linhas_do_corte
    when "dtf" then linhas_do_dtf
    when "tecido" then linhas_do_tecido
    else linhas_da_impressao
    end
  end

  private

  def linhas_da_impressao
    ImpressaoPedidoService.call(@pedido).flat_map do |grupo|
      linhas = grupo.linhas.select(&:arquivo).reject(&:pendencia)
      linhas = linhas.reject { |l| l.refazer_impressao == false } if @etapa.chave == "impressao"
      linhas.map { |linha| da_impressao(grupo.item, linha) }
    end
  end

  def da_impressao(item, linha)
    Linha.new(chave: self.class.chave_da_impressao(item, linha),
              referencia: item.uuid, item: item, peca: linha.peca, tamanho: linha.tamanho, arquivo: linha.arquivo,
              lado: linha.lado, materia_prima: item.materia_prima, pecas: linha.pecas, origem: linha.origem,
              esperado: esperado(linha.pecas) { linha.metros_esperados(@largura_papel_mm) },
              corte_chave: (self.class.chave_do_corte(linha.peca, linha.tamanho, item.materia_prima) if linha.corta),
              dispensa: (linha.refazer_impressao == false ? [ "impressao" ] : []))
  end

  def linhas_do_corte
    ProducaoPedidoService.call(@pedido).select(&:tamanho).map do |linha|
      Linha.new(chave: self.class.chave_do_corte(linha.peca, linha.tamanho, linha.materia_prima), peca: linha.peca,
                tamanho: linha.tamanho, materia_prima: linha.materia_prima, pecas: linha.pecas,
                esperado: esperado(linha.pecas) { linha.metros_esperados })
    end
  end

  def linhas_do_dtf
    EncaixeDoPedidoDtf.call(@pedido).select(&:arquivo).reject(&:pendencia).map do |encaixe|
      Linha.new(chave: self.class.chave_do_dtf(encaixe), referencia: encaixe.item.uuid, item: encaixe.item,
                arquivo: encaixe.arquivo, pecas: encaixe.impressas, encaixe: encaixe, dispensa: [],
                esperado: esperado(encaixe.impressas) { encaixe.metros })
    end
  end

  # An item without fabric, meters or width is a draft's pendência.
  def linhas_do_tecido
    @pedido.itens_pedido.includes(:arte, :materia_prima, arquivo: :approved_version).order(:id)
           .select { |item| item.materia_prima && item.metros.to_f.positive? && item.largura_efetiva_mm }
           .map do |item|
      Linha.new(chave: self.class.chave_do_tecido(item), referencia: item.uuid, item: item, arquivo: item.arquivo,
                materia_prima: item.materia_prima, dispensa: [], esperado: item.metros.to_f)
    end
  end

  # Pieces when the stage counts them, else the metragem the block gives.
  def esperado(pecas)
    @etapa.esperado == "pecas" ? pecas : yield
  end
end
