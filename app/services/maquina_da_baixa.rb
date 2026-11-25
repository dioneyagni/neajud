# The machine a baixa says (Máquinas 4/5a, decided 20–24/11/2026): one per
# baixa (Q2a), among the active ones doing the stage's trabalho; a stage
# with no machine (the Conferência, a trabalho nobody registered) takes
# none. With one machine it needs no choice. The editor opens on the
# sugerida: the machine of the stage's last baixa, else the one it is held
# on (2/5b), else where the queue put it (Q4a: "a programada").
#
# Usage: MaquinaDaBaixa.opcoes(pedido, etapa).map(&:nome)            # => ["Calandra 2", "Calandra 3"]
#        MaquinaDaBaixa.escolher(pedido, etapa, calandra_2.uuid)       # => calandra_2
#        MaquinaDaBaixa.sugerida(pedido, etapa, fixacoes: f) { fila }  # => #<Sugestao maquina=… origem=:baixa>
#        MaquinaDaBaixa.mover_presa(baixa, etapa, movimentos: MovimentoDaFila) # => the movement, or nil
class MaquinaDaBaixa
  # The machine given doesn't do the stage, or one is missing.
  class Invalida < StandardError; end

  # origem: :baixa (the last one's), :presa (held there) or :programada (the queue's).
  Sugestao = Struct.new(:maquina, :origem, keyword_init: true)

  # The active machines doing the stage's trabalho, the first registered first.
  # maquinas: Maquina, visible to who asks (the team's).
  def self.opcoes(pedido, etapa, maquinas: Maquina)
    trabalho = TrabalhosDeMaquina.da_etapa(pedido.tipo, etapa.chave)
    return [] unless trabalho

    maquinas.ativos.where(id: TrabalhoDaMaquina.where(trabalho: trabalho.chave).select(:maquina_id)).order(:id).to_a
  end

  # The machine for the uuid given; nil for a stage with none. Raises
  # Invalida naming the machine and the ones expected.
  def self.escolher(pedido, etapa, uuid, maquinas: Maquina)
    opcoes = opcoes(pedido, etapa, maquinas: maquinas)
    raise Invalida, "#{etapa.nome} has no machine; got machine #{uuid.inspect}" if opcoes.empty? && uuid.present?
    return opcoes.first if opcoes.size <= 1 && uuid.blank?
    raise Invalida, "Which machine did the #{etapa.nome}? Expected one of #{nomes(opcoes)}" if uuid.blank?

    opcoes.find { |maquina| maquina.uuid == uuid } ||
      raise(Invalida, "Machine #{uuid.inspect} doesn't do the #{etapa.nome}; expected one of #{nomes(opcoes)}")
  end

  # Where the editor opens; the queue (the block) is only built when
  # neither a baixa nor a hold says it. nil without machines.
  # fixacoes: MovimentoDaFila.fixacoes, visible to who asks.
  def self.sugerida(pedido, etapa, fixacoes:, maquinas: Maquina, &fila)
    opcoes = opcoes(pedido, etapa, maquinas: maquinas)
    return if opcoes.empty?

    ultima = pedido.baixas_producao.vigentes.da_etapa(etapa.chave).where(maquina_id: opcoes.map(&:id)).order(:created_at).last
    return Sugestao.new(maquina: ultima.maquina, origem: :baixa) if ultima

    presa = opcoes.find { |maquina| maquina.id == fixacoes[[ pedido.id, etapa.chave ]]&.para_maquina_id }
    return Sugestao.new(maquina: presa, origem: :presa) if presa

    Sugestao.new(maquina: programada(pedido, etapa, opcoes, fila.call), origem: :programada)
  end

  # The baixa on another machine than the one the stage was held on (Q1a:
  # the baixa wins): the hold moves to it, as a machine movement made by
  # the baixa — the Histórico da programação says so. nil when nothing changes.
  # movimentos: MovimentoDaFila, visible to who gave the baixa.
  # Usage: MaquinaDaBaixa.mover_presa(baixa, etapa, movimentos: MovimentoDaFila)
  def self.mover_presa(baixa, etapa, movimentos:)
    return unless baixa.maquina && baixa.user

    ultimo = movimentos.trocas_de_maquina.where(pedido_id: baixa.pedido_id, etapa: baixa.etapa).order(:id).last
    return if ultimo&.para_maquina_id.nil? || ultimo.para_maquina_id == baixa.maquina_id

    movimentos.create!(pedido: baixa.pedido, user: baixa.user, etapa: baixa.etapa, setor: FilaDeProducao.setor_de(etapa),
                       de_maquina: ultimo.para_maquina, para_maquina: baixa.maquina, baixa_producao: baixa)
  end

  def self.programada(pedido, etapa, opcoes, fila)
    vez = fila.previsao(pedido)&.vezes&.find { |outra| outra.etapa.chave == etapa.chave }
    opcoes.find { |maquina| maquina.id == vez&.maquina&.id } || opcoes.first
  end

  def self.nomes(maquinas)
    maquinas.map(&:nome).join(", ")
  end
  private_class_method :programada, :nomes
end
