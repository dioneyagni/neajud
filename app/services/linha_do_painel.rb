# One pedido's row of the Painel (Painel 1/4, decided 04/11/2026): a cell per
# column (CelulaDoPainel), its block, the % done, start, deadline, what holds
# it and the path its production takes.
#
# Columns (Q4): Arquivos │ Comercial │ Material │ Impressão │ Corte │
# Estamparia (the tecido's Calandra too) │ Conferência │ Entrega. The
# Dublagem ones come with Dublagem 5b (Painel 4/4).
#
# A cliente final sees no material detail (the empresa's paper is not his,
# AguardandoMaterialHelper) and the factory's pendências as "em análise".
#
# Usage: linha = LinhaDoPainel.call(pedido, aguardando: AguardandoMaterial.call)
#        linha.celulas["corte"].texto # => "3/8"
#        linha.bloco                  # => :em_andamento
class LinhaDoPainel
  COLUNAS = { "arquivos" => "Arquivos", "comercial" => "Comercial", "material" => "Material", "impressao" => "Impressão",
              "corte" => "Corte", "estamparia" => "Estamparia", "conferencia" => "Conferência", "entrega" => "Entrega" }.freeze
  # A stage shown in another stage's column.
  COLUNA_DA_ETAPA = { "calandra" => "estamparia" }.freeze
  # The pendências that are about files (the rest are the Comercial's).
  DOS_ARQUIVOS = %i[arquivo_excluido sem_corte sem_arquivo sem_lado sem_medida nao_cabe nao_cabe_em_pe nao_cabe_girada].freeze

  attr_reader :pedido, :celulas, :estados, :bloqueios, :faltas

  # baixas: the pedido's baixas in force, read with the others' (PainelDeProducao).
  def self.call(pedido, aguardando:, baixas: nil, cliente_final: false)
    new(pedido, aguardando, baixas, cliente_final)
  end

  def initialize(pedido, aguardando, baixas, cliente_final)
    @pedido = pedido
    @cliente_final = cliente_final
    @faltas = aguardando.do_pedido(pedido)
    @bloqueios = pedido.confirmavel? ? PedidoBloqueiosService.call(pedido) : []
    @estados = pedido.saiu_do_rascunho? ? EstadoDasEtapas.call(pedido, baixas: baixas) : {}
    @celulas = montar_celulas
  end

  # :em_andamento, :prontos, :pendentes or :entregues.
  def bloco
    return :entregues if pedido.status == "entregue"
    return :pendentes if Pedido::ANTES_DA_CONFIRMACAO.include?(pedido.status) || faltas.any?

    # A baixa puts it in production (Pedido#iniciar_producao!); older
    # pedidos may still say confirmado with baixas given.
    pedido.status == "em_producao" || primeira_baixa ? :em_andamento : :prontos
  end

  # Lines done over the lines of every stage. Usage: linha.percentual # => 45
  def percentual
    return 100 if pedido.status == "entregue"

    producao = celulas_de_producao(celulas)
    total = producao.sum { |c| c.total.to_i }
    total.zero? ? 0 : producao.sum { |c| c.feitas.to_i } * 100 / total
  end

  # When it started: its confirmation, else (confirmed before Painel 1/4) its first baixa.
  def inicio
    pedido.confirmado_em || primeira_baixa&.created_at
  end

  # The arrival order: confirmation, else creation (a draft, or an old pedido).
  def chegada
    pedido.confirmado_em || pedido.created_at
  end

  def atrasado?(hoje = Date.current)
    pedido.prazo_entrega.present? && pedido.status != "entregue" && pedido.prazo_entrega < hoje
  end

  def pendencia?
    celulas.values.any? { |c| c.estado == :pendencia } || faltas.any?
  end

  # What holds it now, in the order it is settled; nil when nothing does.
  # Usage: linha.trava # => "Estamparia espera Corte"
  def trava
    presa = celulas.find { |_, c| %i[pendencia travada].include?(c.estado) }
    presa && "#{COLUNAS.fetch(presa.first)}: #{presa.last.detalhe || presa.last.texto}"
  end

  # The stages in steps (CaminhoDoPedido), each with its column.
  def caminho
    @caminho ||= CaminhoDoPedido.call(pedido)
  end

  def coluna_da_etapa(etapa)
    COLUNA_DA_ETAPA.fetch(etapa.chave, etapa.chave)
  end

  private

  def montar_celulas
    celulas = COLUNAS.keys.index_with { CelulaDoPainel.nova(:nao_tem) }
    celulas.merge!("arquivos" => celula_dos_arquivos, "comercial" => celula_comercial, "material" => celula_do_material)
    celulas.merge!(celulas_das_etapas)
    celulas.merge!("entrega" => celula_da_entrega(celulas))
  end

  # A draft's stages are not computed (its lines still follow the artes): "—".
  def celulas_das_etapas
    return estados.to_h { |chave, situacoes| [ COLUNA_DA_ETAPA.fetch(chave, chave), CelulaDoPainel.da_etapa(situacoes.values, confirmado: pedido.em_producao?) ] } if estados.any?
    return {} if pedido.itens_pedido.empty?

    EtapasProducao.do_tipo(pedido.tipo, pedido: pedido).to_h { |etapa| [ coluna_da_etapa(etapa), CelulaDoPainel.nova(:ainda_nao, "—") ] }
  end

  def celulas_de_producao(celulas)
    estados.keys.map { |chave| celulas[COLUNA_DA_ETAPA.fetch(chave, chave)] }
  end

  def celula_dos_arquivos
    dos_arquivos = bloqueios.select { |b| DOS_ARQUIVOS.include?(b.tipo) }
    return CelulaDoPainel.nova(:pendencia, contagem(dos_arquivos.size, "pendência"), descricoes(dos_arquivos)) if dos_arquivos.any?
    return CelulaDoPainel.nova(:nao_tem) if pedido.itens_pedido.empty?

    CelulaDoPainel.nova(:feita, "ok")
  end

  def celula_comercial
    outros = bloqueios.reject { |b| DOS_ARQUIVOS.include?(b.tipo) }
    return CelulaDoPainel.nova(:pendencia, contagem(outros.size, "pendência"), descricoes(outros)) if outros.any?
    return CelulaDoPainel.nova(:pendencia, "sem itens") if pedido.itens_pedido.empty? && pedido.confirmavel?
    return celula_da_aprovacao || CelulaDoPainel.nova(:andamento, pedido.status) if pedido.confirmavel?

    CelulaDoPainel.nova(:feita, "confirmado", ("em #{pedido.confirmado_em.strftime("%d/%m %H:%M")}" if pedido.confirmado_em))
  end

  # A draft whose artes wait for the client's approval (Aprovavel).
  def celula_da_aprovacao
    estados = pedido.itens_pedido.filter_map(&:arte).uniq.map(&:estado_aprovacao)
    return CelulaDoPainel.nova(:pendencia, "alteração pedida", "o cliente pediu alteração de uma arte") if estados.include?(:alteracao_pedida)

    CelulaDoPainel.nova(:andamento, "aguarda aprovação", "arte enviada ao cliente, sem resposta") if estados.include?(:aguardando)
  end

  def celula_do_material
    return CelulaDoPainel.nova(:ainda_nao, "—") if pedido.confirmavel?
    return CelulaDoPainel.nova(:feita, "ok") if faltas.empty?

    dublagem, material = faltas.partition { |falta| falta.materia_prima.dublado? }
    texto = [ ("material" if material.any?), ("dublagem" if dublagem.any?) ].compact.join(" e ")
    detalhe = faltas.map { |f| "#{f.materia_prima.nome_completo} · faltam #{metros(f.metros)}" }.join("; ") unless @cliente_final
    CelulaDoPainel.nova(:travada, "aguarda #{texto}", detalhe)
  end

  def celula_da_entrega(celulas)
    return CelulaDoPainel.nova(:feita, "entregue", ("em #{pedido.entregue_em.strftime("%d/%m %H:%M")}" if pedido.entregue_em)) if pedido.status == "entregue"
    return CelulaDoPainel.nova(:ainda_nao, "—") unless pedido.em_producao? && estados.any?

    pronto = celulas_de_producao(celulas).all? { |c| c.estado == :feita }
    pronto ? CelulaDoPainel.nova(:pode_comecar, "pronto p/ entregar") : CelulaDoPainel.nova(:ainda_nao, "—")
  end

  def descricoes(bloqueios)
    bloqueios.map { |b| @cliente_final && PedidoBloqueiosService::DA_FABRICA.include?(b.tipo) ? "em análise pela fábrica" : b.descricao }.uniq.join("; ")
  end

  def metros(valor)
    "#{ActiveSupport::NumberHelper.number_to_rounded(valor, precision: 2, strip_insignificant_zeros: true, separator: ",")} m"
  end

  def contagem(numero, palavra)
    "#{numero} #{palavra}#{"s" if numero != 1}"
  end

  def primeira_baixa
    estados.values.flat_map { |situacoes| situacoes.values.filter_map(&:baixa) }.min_by(&:created_at)
  end
end
