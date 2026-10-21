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
# - A stage marked `reposicao` (the Conferência, 4/4) with fewer pieces than
#   expected: the lines are counted first (:contar, with each line's count
#   and the stages to redo); the pieces short go to the pedido's open
#   reposição (AcumularReposicaoService), released when the Conferência ends
#   (LiberarReposicaoService) — decided 09/10/2026.
# - The stock (Etapa 2.3e, decided 20/10/2026): a stage that takes material
#   (EtapasProducao `material`) adjusts it by the real (AjusteDaBaixa). Lines
#   of several materials ask one measure each (`medidas`, material uuid =>
#   meters; `medida` is their sum), each checked against its own expected.
#
# Usage: RegistrarBaixaService.call(pedido, etapa: "corte", nivel: "pedido", medida: "12,4", confirmar: false, user: u, changed_by: ip)
#   # => #<Resultado estado=:ok baixa=#<BaixaProducao …>>
class RegistrarBaixaService
  Resultado = Struct.new(:estado, :baixa, :esperado, :mensagem, :linhas, :contagem, keyword_init: true)
  STATUS = Pedido::EM_PRODUCAO

  def self.call(pedido, **dados)
    new(pedido, **dados).call
  end

  def initialize(pedido, etapa:, nivel:, medida:, alvo: nil, confirmar: false, contagens: nil, refazer: nil, medidas: nil, user: nil, changed_by: nil)
    @pedido = pedido
    @etapa = EtapasProducao.etapa(pedido.tipo, etapa, pedido: pedido)
    @nivel = nivel.to_s
    @alvo = alvo.to_s
    @medida = medida.to_s.tr(",", ".")
    @confirmar = confirmar
    @contagens = contagens
    @refazer = refazer
    @medidas = (medidas || {}).to_h.transform_keys(&:to_s).transform_values { |valor| valor.to_s.tr(",", ".").strip }
    @medida = format("%.4f", @medidas.values.sum(&:to_d)) if @medida.blank? && @medidas.any?
    @autoria = { user: user, changed_by: changed_by }
  end

  def call
    erro = erro_de_entrada || erro_das_medidas || contagem&.erro
    return Resultado.new(estado: :erro, mensagem: erro) if erro
    return pedir_contagem if contagem&.contar?

    esperado = linhas.sum { |l| l.esperado.to_f }
    faltas = contagem ? contagem.faltas : []
    return aviso(esperado) if faltas.empty? && fora?(esperado) && !@confirmar

    Resultado.new(estado: :ok, baixa: registrar(esperado, faltas), esperado: esperado)
  end

  # A line as the factory names it: "Lateral 29-30 ESQ".
  def self.rotulo(linha)
    [ linha.peca&.nome || "Sem peça", linha.tamanho&.nome, LadoNaArte::ABREVIACOES[linha.lado] ].compact.join(" ")
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

  def registrar(esperado, faltas)
    medida = contagem ? contagem.medida : @medida.to_d
    baixa = BaixaProducao.transaction do
      @pedido.baixas_producao.create!(etapa: @etapa.chave, nivel: @nivel, linhas: linhas.map(&:chave), medida: medida,
                                      esperado: (esperado if esperado.positive?), contagens: contagem&.por_linha || {},
                                      medidas: medidas_por_material, fora_da_faixa: faltas.empty? && fora?(esperado), **@autoria)
                    .tap { |nova| AjusteDaBaixa.call(nova, linhas) }
    end
    baixa.update!(reposicao: AcumularReposicaoService.call(@pedido, faltas)) if faltas.any?
    @pedido.iniciar_producao!
    liberar_reposicao_ao_terminar
    baixa
  end

  # The Conferência's last line sends the open reposição to production.
  def liberar_reposicao_ao_terminar
    return unless @etapa.reposicao

    @feitas = nil
    LiberarReposicaoService.call(@pedido) if todas.all? { |linha| estado_da(linha).first == :feita }
  end

  # The Conferência's count (Etapa 2.2, 4/4); nil for other stages.
  def contagem
    return nil unless @etapa.reposicao

    @contagem ||= ContagemDaConferencia.new(nivel: @nivel, linhas: linhas, medida: @medida, contagens: @contagens, refazer: @refazer)
  end

  def pedir_contagem
    esperado = linhas.sum { |l| l.esperado.to_i }
    falta = esperado - @medida.to_i
    Resultado.new(estado: :contar, linhas: linhas, contagem: contagem,
                  mensagem: "#{falta == 1 ? "Falta 1 peça" : "Faltam #{falta} peças"} das #{esperado} esperadas. Confira a contagem de cada linha e marque o que refazer: as peças que faltarem vão para a reposição.")
  end


  def erro_de_entrada
    return "This pedido is #{@pedido.status}: only a confirmed pedido in production takes baixas." unless @pedido.em_producao?
    return "#{@etapa.nome} takes no baixa by #{@nivel.inspect}; expected one of #{@etapa.niveis.join(", ")}." unless @etapa.niveis.include?(@nivel)
    return "Measure #{@medida.inspect} is not a number of #{@etapa.metragem? ? "meters" : "pieces"}." unless @medida.match?(/\A\d+(\.\d+)?\z/)

    erro_das_linhas
  end

  # Several materials: each one's measure, a number (Etapa 2.3e).
  def erro_das_medidas
    return nil unless varios_materiais?

    sem = por_material.keys.reject { |material| @medidas[material.uuid].to_s.match?(/\A\d+(\.\d+)?\z/) }
    return "Missing the measure of #{sem.map(&:nome_completo).join(", ")}: this baixa covers several materials, one measure (meters) each." if sem.any?

    @medida = format("%.4f", medidas_por_material.values.sum(&:to_d))
    nil
  end

  # The expected meters of each material the lines take (Etapa 2.3e).
  def por_material
    @por_material ||= MateriaisDasLinhas.por_material(@pedido, @etapa, linhas)
  end

  def varios_materiais?
    por_material.size > 1
  end

  def medidas_por_material
    varios_materiais? ? por_material.keys.to_h { |material| [ material.uuid, @medidas[material.uuid] ] } : {}
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

    # A reposição's line may skip printing or cutting again (09/10/2026).
    travas = @etapa.trava - Array(linha.dispensa)
    esperando = travas.find { |trava| !feitas(trava).include?(chave_na(trava, linha)) && chave_na(trava, linha) }
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

  # Outside the dono's band: the whole measure, or any material's own.
  def fora?(esperado)
    varios_materiais? ? materiais_fora.any? : fora_da_faixa?(esperado, @medida.to_d)
  end

  def materiais_fora
    por_material.select { |material, esperado| fora_da_faixa?(esperado, @medidas[material.uuid].to_d) }
  end

  def fora_da_faixa?(esperado, medida)
    return false unless esperado.positive?

    # Without an empresa yet, its defaults (-10% / +25%).
    empresa = Empresa.atual || Empresa.new
    medida < esperado * (100 - empresa.tolerancia_abaixo_pct) / 100.0 || medida > esperado * (100 + empresa.tolerancia_acima_pct) / 100.0
  end

  def aviso(esperado)
    return aviso_por_material if varios_materiais?

    unidade = " #{@etapa.unidade_da_medida}"
    Resultado.new(estado: :aviso, esperado: esperado,
                  mensagem: "Esperado ~#{metros_br(esperado)}#{unidade}, você informou #{@medida.tr(".", ",")}#{unidade}. Confira e corrija, ou confirme assim mesmo.")
  end

  def aviso_por_material
    textos = materiais_fora.map { |material, esperado| "#{material.nome_completo}: esperado ~#{metros_br(esperado)} m, você informou #{@medidas[material.uuid].tr(".", ",")} m" }
    Resultado.new(estado: :aviso, esperado: por_material.values.sum, mensagem: "#{textos.join("; ")}. Confira e corrija, ou confirme assim mesmo.")
  end

  def metros_br(valor)
    format("%.2f", valor).tr(".", ",").delete_suffix(",00")
  end
end
