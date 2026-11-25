# Saves a stop (Máquinas 3/5a, decided 24/11/2026): who made it, the
# machines picked (Q1a), what it does to the queue kept with it (Q3a: no
# confirmation; Q4a: `impacto`), and each pedido pushed told in its
# history like a move's ("qui 12/11 → sex 13/11", Painel 3/4a Q4).
#
# dados: { nome:, data:, data_fim:, turno_uuid:, etapa:, maquina_uuids: [] }
# maquinas: the Maquina scope visible to who saves.
#
# Usage: resultado = SalvarParada.call(dados, fila: FilaDeProducao.call, maquinas: Maquina, user: Current.user)
#        resultado.parada.impacto["atrasam"] # => 3, or resultado.erro
class SalvarParada
  Resultado = Struct.new(:parada, :impacto, :erro, keyword_init: true)

  def self.call(dados, fila:, maquinas:, user:)
    new(dados.to_h.with_indifferent_access, fila, maquinas, user).call
  end

  def initialize(dados, fila, maquinas, user)
    @dados, @fila, @maquinas, @user = dados, fila, maquinas, user
  end

  def call
    parada = montar
    return Resultado.new(parada: parada, erro: parada.errors.full_messages.to_sentence) unless parada.valid?

    impacto = ImpactoDaParada.call(parada, @fila)
    ExcecaoCalendario.transaction do
      parada.update!(impacto: impacto.registro)
      impacto.empurrados.each { |empurrado| AvisoDePrevisao.call(empurrado.pedido, de: empurrado.de, para: empurrado.para, user: @user) }
    end
    Resultado.new(parada: parada, impacto: impacto)
  end

  private

  def montar
    ExcecaoCalendario.new(@dados.slice(:nome, :data, :data_fim, :turno_uuid, :etapa).merge(origem: "manual", user: @user)).tap do |parada|
      parada.data_fim = nil if parada.data_fim.blank?
      maquinas_pedidas.each { |maquina| parada.paradas_das_maquinas.build(maquina: maquina) }
    end
  end

  # An unknown uuid raises (RecordNotFound), like a turno's.
  def maquinas_pedidas
    uuids = Array(@dados[:maquina_uuids]).compact_blank.uniq
    @maquinas.ativos.includes(:trabalhos).where(uuid: uuids).to_a.tap do |achadas|
      faltam = uuids - achadas.map(&:uuid)
      raise ActiveRecord::RecordNotFound, "Machine(s) #{faltam.join(", ")} not found; expected active machines of the stage" if faltam.any?
    end
  end
end
