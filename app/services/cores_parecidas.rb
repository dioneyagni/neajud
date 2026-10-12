# The measured cores lisas nearest to one (Etapa 2.5b, decided 12/10/2026):
# by ΔE2000, among the candidates the caller passes (visiveis(Arte) — a
# client compares only with the colors he sees), within the "parecida"
# limit of config/familias_de_cor.yml; each marked :praticamente_igual
# (≤ 1) or :parecida (≤ 3). A notice, never a block.
#
# Usage: CoresParecidas.call(arte, candidatas: visiveis(Arte))
#        # => [#<struct arte=<Laranja 1>, delta_e=0.8, grau=:praticamente_igual>]
class CoresParecidas
  Parecida = Struct.new(:arte, :delta_e, :grau)

  def self.call(arte, candidatas:, limite: 5)
    lab = arte.cor_medida&.lab
    return [] unless lab

    medidas(candidatas.where.not(id: arte.id)).filter_map { |outra, outro_lab| parecida(outra, DeltaE2000.entre(lab, outro_lab)) }
                                              .sort_by(&:delta_e).first(limite)
  end

  # Whether any measured cor lisa is within the limit — for the gallery card,
  # which goes live to several clients and so never names the other color.
  # Usage: CoresParecidas.alguma?(arte) # => true
  def self.alguma?(arte)
    call(arte, candidatas: Arte.all, limite: 1).any?
  end

  # [[arte, lab]] of the measured cores lisas among the candidates.
  def self.medidas(candidatas)
    versoes = ArquivoVersion.joins(:arquivo).where(arquivos: { arte_id: candidatas.where(tipo: "cor_lisa").select(:id), deleted_at: nil })
                            .where("arquivos.approved_version_id = arquivo_versions.id").where.not(lab_l: nil)
    artes = Arte.where(id: versoes.select("arquivos.arte_id")).index_by(&:id)
    versoes.order("arquivos.id").pluck("arquivos.arte_id", :lab_l, :lab_a, :lab_b).uniq(&:first).map { |arte_id, *lab| [ artes[arte_id], lab ] }
  end
  private_class_method :medidas

  def self.parecida(outra, delta_e)
    return if delta_e > FamiliasDeCor.limite(:parecida)

    Parecida.new(outra, delta_e.round(1), delta_e <= FamiliasDeCor.limite(:praticamente_igual) ? :praticamente_igual : :parecida)
  end
  private_class_method :parecida
end
