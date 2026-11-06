# The Painel's blocks in time (Painel 2/4b, decided 06/11/2026, Q3a): a row
# goes where its next piece of work is in the queue (FilaDeProducao) — its
# reposições' too —, the most urgent first inside each block:
#
#   agora           — in the turno under way, or only the delivery left
#   turno:<início>  — a later turno today ("Hoje · Tarde (14:00–22:00)")
#   amanha          — tomorrow
#   dia:<data>      — a later day
#   sem_previsao    — no stage can be computed (material, rhythm, 90 days)
#   pendentes       — a draft or a sent pedido (its "se confirmar agora")
#   entregues       — delivered (only when asked)
#
# A cliente final sees days only (Q4a): hoje, amanha, dia:<data>.
#
# Usage: blocos = BlocosNoTempo.call(linhas, agora: Time.current)
#        blocos.map { |b| [ b.chave, b.nome, b.linhas.size ] } # => [["agora", "Agora · Manhã (06:00–14:00)", 2], …]
class BlocosNoTempo
  # The blocks with a counter on top (the days come and go).
  CONTADOS = %w[agora hoje sem_previsao pendentes entregues].freeze
  FIXOS = { "sem_previsao" => "Sem previsão", "pendentes" => "Pendentes de início", "entregues" => "Entregues (7 dias)" }.freeze
  # A pedido without deadline sorts after every dated one.
  SEM_PRAZO = Date.new(9999, 12, 31)

  Bloco = Struct.new(:chave, :nome, :linhas, keyword_init: true)

  # entregues: show that block (the page asked for the delivered ones).
  def self.call(linhas, agora:, cliente_final: false, entregues: false)
    new(linhas, agora, cliente_final, entregues).call
  end

  def initialize(linhas, agora, cliente_final, entregues)
    @linhas = linhas
    @agora = agora
    @hoje = agora.to_date
    @cliente_final = cliente_final
    @entregues = entregues
    @nomes = {}
  end

  def call
    grupos = @linhas.group_by { |linha| chave_de(linha) }
    chaves = (grupos.keys + fixos).uniq.sort_by { |chave| ordem_do_bloco(chave) }
    chaves.map { |chave| Bloco.new(chave: chave, nome: @nomes.fetch(chave) { nome_fixo(chave) }, linhas: ordenar(grupos.fetch(chave, []))) }
  end

  private

  # The empty ones that still show, so the page says "Nenhum pedido.".
  def fixos
    [ (@cliente_final ? "hoje" : "agora"), "sem_previsao", "pendentes", ("entregues" if @entregues) ].compact
  end

  def chave_de(linha)
    return "entregues" if linha.pedido.status == "entregue"
    return "pendentes" if linha.previsao.nil? || linha.previsao.se_confirmar

    trecho = proxima(linha)
    return chave_do_trecho(trecho) if trecho
    return fixos.first if linha.com_reposicoes.all? { |l| l.previsao&.pronta? }

    "sem_previsao"
  end

  def proxima(linha)
    linha.com_reposicoes.filter_map { |l| l.previsao&.proxima(@agora) }.min_by(&:inicio)
  end

  def chave_do_trecho(trecho)
    ocorrencia = trecho.ocorrencia
    return dia(ocorrencia.data) if @cliente_final
    return nomear("agora", "Agora · #{ocorrencia.rotulo}") if ocorrencia.contem?(@agora)
    return nomear("turno:#{ocorrencia.inicio.iso8601}", "Hoje · #{ocorrencia.rotulo}") if ocorrencia.data == @hoje

    dia(ocorrencia.data)
  end

  def dia(data)
    return nomear("hoje", "Hoje") if data <= @hoje
    return nomear("amanha", "Amanhã · #{Turno.dia_com_semana(data)}") if data == @hoje + 1

    nomear("dia:#{data.iso8601}", "#{Turno.dia_com_semana(data)} · em #{(data - @hoje).to_i} dias")
  end

  def nomear(chave, nome)
    @nomes[chave] ||= nome
    chave
  end

  def nome_fixo(chave)
    FIXOS.fetch(chave) { chave == "agora" ? "Agora" : "Hoje" }
  end

  # agora/hoje, today's turnos, tomorrow, the days, then the fixed ones.
  def ordem_do_bloco(chave)
    tipo, valor = chave.split(":", 2)
    posicao = %w[agora hoje turno amanha dia sem_previsao pendentes entregues].index(tipo)
    [ posicao, valor.to_s ]
  end

  # By the next piece's time, the late ones ahead of the same time (Q6a);
  # without time, late, pendência, deadline, arrival.
  def ordenar(linhas)
    linhas.sort_by do |linha|
      [ proxima(linha)&.inicio || @agora, linha.vai_atrasar? || linha.atrasado?(@hoje) ? 0 : 1, linha.pendencia? ? 0 : 1, linha.prazo || SEM_PRAZO, linha.chegada ]
    end
  end
end
