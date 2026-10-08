# Registers a production stage's baixa (Etapa 2.2, 2/3; decided 07/10/2026).
#
# - Which lines: one (`alvo` = its key), a referência (`alvo` = the item's
#   uuid) or the whole pedido — only the open ones, and only those whose
#   locked stages are done (a part "não corta" skips the Corte lock). A line
#   still waiting is refused, saying for what.
# - What it expects: the covered lines' expected (meters from the files, or
#   pieces). A measure outside the dono's band (Empresa tolerâncias) comes
#   back as :aviso until the operator confirms it; then it is saved marked
#   fora_da_faixa.
#
# Usage: RegistrarBaixaService.call(pedido, etapa: "corte", nivel: "pedido", medida: "12,4", confirmar: false, user: u, changed_by: ip)
#   # => #<Resultado estado=:ok baixa=#<BaixaProducao …>>
class RegistrarBaixaService
  Resultado = Struct.new(:estado, :baixa, :esperado, :mensagem, keyword_init: true)
  STATUS = %w[confirmado].freeze

  def self.call(pedido, **dados)
    new(pedido, **dados).call
  end

  def initialize(pedido, etapa:, nivel:, medida:, alvo: nil, confirmar: false, user: nil, changed_by: nil)
    @pedido = pedido
    @etapa = EtapasProducao.etapa(pedido.tipo, etapa)
    @nivel = nivel.to_s
    @alvo = alvo.to_s
    @medida = medida.to_s.tr(",", ".")
    @confirmar = confirmar
    @autoria = { user: user, changed_by: changed_by }
  end

  def call
    erro = erro_de_entrada
    return Resultado.new(estado: :erro, mensagem: erro) if erro

    esperado = linhas.sum { |l| l.esperado.to_f }
    return aviso(esperado) if fora_da_faixa?(esperado) && !@confirmar

    baixa = @pedido.baixas_producao.create!(etapa: @etapa.chave, nivel: @nivel, linhas: linhas.map(&:chave), medida: @medida.to_d,
                                            esperado: (esperado if esperado.positive?), fora_da_faixa: fora_da_faixa?(esperado), **@autoria)
    Resultado.new(estado: :ok, baixa: baixa, esperado: esperado)
  end

  Situacao = Struct.new(:linha, :estado, :baixa, :aguardando, keyword_init: true)

  # Every line of this stage by key: :feita (with its baixa), :aguardando
  # (the stage it waits for) or :aberta. Shared by the pages.
  # Usage: RegistrarBaixaService.situacao(pedido, "estamparia")["…/…"].aguardando # => "Corte"
  def self.situacao(pedido, etapa)
    new(pedido, etapa: etapa, nivel: "pedido", medida: "0").situacao
  end

  def situacao
    todas.to_h do |linha|
      estado, aguardando = estado_da(linha)
      [ linha.chave, Situacao.new(linha: linha, estado: estado, aguardando: aguardando, baixa: baixas_por_chave[linha.chave]) ]
    end
  end

  private

  def erro_de_entrada
    return "This pedido is #{@pedido.status}: only a confirmed pedido takes baixas." unless STATUS.include?(@pedido.status) && !@pedido.excluido?
    return "#{@etapa.nome} takes no baixa by #{@nivel.inspect}; expected one of #{@etapa.niveis.join(", ")}." unless @etapa.niveis.include?(@nivel)
    return "Measure #{@medida.inspect} is not a number of #{@etapa.metragem? ? "meters" : "pieces"}." unless @medida.match?(/\A\d+(\.\d+)?\z/)

    erro_das_linhas
  end

  def erro_das_linhas
    pedidas = todas.select { |l| alvo?(l) }
    return "No #{@etapa.nome} line #{@alvo.inspect} in this pedido." if pedidas.empty?

    esperando = pedidas.filter_map { |l| estado_da(l) }.find { |estado, _| estado == :aguardando }
    return "Waiting for #{esperando.last}: this line can't have its #{@etapa.nome} baixa yet." if @nivel == "linha" && esperando
    return "Nothing open to give #{@etapa.nome}'s baixa (done or waiting for #{(@etapa.trava.map { |t| EtapasProducao.etapa(@pedido.tipo, t).nome }).join(", ")})." if linhas.empty?

    nil
  end

  def alvo?(linha)
    case @nivel
    when "linha" then linha.chave == @alvo
    when "referencia" then linha.referencia == @alvo
    else true
    end
  end

  # The lines this baixa covers: asked for, open and not waiting.
  def linhas
    @linhas ||= todas.select { |l| alvo?(l) && estado_da(l).first == :aberta }
  end

  def todas
    @todas ||= LinhasDeProducao.call(@pedido, @etapa)
  end

  def estado_da(linha)
    return [ :feita ] if feitas(@etapa.chave).include?(linha.chave)

    esperando = @etapa.trava.find { |trava| !feitas(trava).include?(chave_na(trava, linha)) && chave_na(trava, linha) }
    esperando ? [ :aguardando, EtapasProducao.etapa(@pedido.tipo, esperando).nome ] : [ :aberta ]
  end

  # The line's key in a locking stage: its Corte line, or itself.
  def chave_na(trava, linha)
    EtapasProducao.etapa(@pedido.tipo, trava).linhas == "corte" ? linha.corte_chave : linha.chave
  end

  def baixas_por_chave
    @baixas_por_chave ||= @pedido.baixas_producao.vigentes.da_etapa(@etapa.chave).includes(:user).order(:created_at)
                                 .each_with_object({}) { |baixa, mapa| baixa.linhas.each { |chave| mapa[chave] ||= baixa } }
  end

  def feitas(etapa)
    @feitas ||= {}
    @feitas[etapa] ||= @pedido.baixas_producao.vigentes.da_etapa(etapa).feitas
  end

  def fora_da_faixa?(esperado)
    return false unless esperado.positive?

    # Without an empresa yet, its defaults (-10% / +25%).
    empresa = Empresa.atual || Empresa.new
    medida = @medida.to_d
    medida < esperado * (100 - empresa.tolerancia_abaixo_pct) / 100.0 || medida > esperado * (100 + empresa.tolerancia_acima_pct) / 100.0
  end

  def aviso(esperado)
    unidade = @etapa.metragem? ? " m" : " peças"
    Resultado.new(estado: :aviso, esperado: esperado,
                  mensagem: "Esperado ~#{format("%.2f", esperado).tr(".", ",").delete_suffix(",00")}#{unidade}, você informou #{@medida.tr(".", ",")}#{unidade}. Confira e corrija, ou confirme assim mesmo.")
  end
end
