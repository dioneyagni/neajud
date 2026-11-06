# A work shift the dono registers (Painel 2/4a, decided 05/11/2026): a name,
# its hours and the days of the week it starts on. One that ends at or before
# its start crosses midnight and belongs to the day it starts (Q10a): the
# Friday "Noite 22:00–06:00" ends on Saturday morning. Two turnos may not
# overlap anywhere in the week. Trashed, not deleted: the measured rhythm
# (RitmoMedido) reads past baixas by the turno they fell in.
#
# Usage: Turno.create!(nome: "Manhã", inicio: "06:00", fim: "14:00", dias: [1, 2, 3, 4, 5, 6])
#        turno.horario # => "06:00–14:00"
class Turno < ApplicationRecord
  include GeraUuid
  include Excluivel

  DIAS = %w[dom seg ter qua qui sex sáb].freeze
  MINUTOS_DO_DIA = 24 * 60
  MINUTOS_DA_SEMANA = 7 * MINUTOS_DO_DIA

  validates :nome, presence: true
  validates :inicio_min, :fim_min, numericality: { only_integer: true, in: 0...MINUTOS_DO_DIA, message: "must be a time of day like 06:00" }
  validate :dias_validos
  validate :nome_unico
  validate :nao_tem_duracao_zero
  validate :nao_sobrepoe

  # "06:00" as typed in the form's time field.
  def inicio=(hhmm)
    self.inicio_min = self.class.minutos(hhmm)
  end

  def fim=(hhmm)
    self.fim_min = self.class.minutos(hhmm)
  end

  def inicio
    self.class.hhmm(inicio_min)
  end

  def fim
    self.class.hhmm(fim_min)
  end

  # Back from the trash only if it still fits: another turno may have taken
  # its hours meanwhile. Raises ActiveRecord::RecordInvalid naming the overlap.
  def restaurar!(**autoria)
    self.deleted_at = nil
    raise ActiveRecord::RecordInvalid, self unless valid?

    super
  end

  # Usage: Turno.minutos("06:30") # => 390; nil for anything else
  def self.minutos(hhmm)
    texto = hhmm.to_s.strip
    return unless texto.match?(/\A([01]?\d|2[0-3]):[0-5]\d\z/)

    horas, minutos = texto.split(":").map(&:to_i)
    (horas * 60) + minutos
  end

  def self.hhmm(minutos)
    minutos && format("%02d:%02d", minutos / 60, minutos % 60)
  end

  def duracao_min
    (fim_min - inicio_min) % MINUTOS_DO_DIA
  end

  # Usage: turno.horas # => 8.0
  def horas
    duracao_min / 60.0
  end

  def atravessa_meia_noite?
    fim_min <= inicio_min
  end

  def horario
    "#{inicio}–#{fim}"
  end

  # Usage: turno.rotulo_dos_dias # => "seg a sáb" or "seg, qua, sex"
  def rotulo_dos_dias
    ordenados = dias.sort
    return DIAS.values_at(*ordenados).join(", ") if ordenados.size < 3 || ordenados.each_cons(2).any? { |a, b| b != a + 1 }

    "#{DIAS[ordenados.first]} a #{DIAS[ordenados.last]}"
  end

  def trabalha_em?(data)
    dias.include?(data.wday)
  end

  # Its stretches in the week, in minutes from Sunday 00:00; one crossing
  # Saturday night wraps to Sunday morning.
  def trechos_da_semana
    dias.flat_map do |dia|
      inicio = (dia * MINUTOS_DO_DIA) + inicio_min
      fim = inicio + duracao_min
      fim <= MINUTOS_DA_SEMANA ? [ inicio...fim ] : [ inicio...MINUTOS_DA_SEMANA, 0...(fim - MINUTOS_DA_SEMANA) ]
    end
  end

  # The day of the week and the time they first meet, or nil.
  # Usage: manha.sobreposicao_com(tarde) # => "seg 13:00"
  def sobreposicao_com(outro)
    trechos_da_semana.product(outro.trechos_da_semana).each do |meu, dele|
      comeco = [ meu.begin, dele.begin ].max
      return "#{DIAS[comeco / MINUTOS_DO_DIA]} #{self.class.hhmm(comeco % MINUTOS_DO_DIA)}" if comeco < [ meu.end, dele.end ].min
    end
    nil
  end

  private

  def dias_validos
    self.dias = Array(dias).reject(&:blank?).map(&:to_i).uniq.sort
    return errors.add(:dias, "are missing: choose at least one day of the week") if dias.empty?

    invalidos = dias.reject { |dia| (0..6).cover?(dia) }
    errors.add(:dias, "#{invalidos.inspect} are not days of the week; expected 0 (Sunday) to 6 (Saturday)") if invalidos.any?
  end

  def nome_unico
    return if nome.blank? || outros.none? { |turno| turno.nome.casecmp?(nome.strip) }

    errors.add(:nome, "\"#{nome}\" is already a turno; expected a different name")
  end

  def nao_tem_duracao_zero
    errors.add(:fim, "#{fim} is the same as the start; expected a turno that lasts") if inicio_min && inicio_min == fim_min
  end

  # Checked only once the hours and days are valid.
  def nao_sobrepoe
    return if errors.any?

    outros.each do |outro|
      quando = sobreposicao_com(outro)
      errors.add(:base, "#{nome} #{horario} (#{rotulo_dos_dias}) overlaps #{outro.nome} #{outro.horario} (#{outro.rotulo_dos_dias}) on #{quando}; expected turnos that don't cross") if quando
    end
  end

  def outros
    Turno.ativos.where.not(id: id).to_a
  end
end
