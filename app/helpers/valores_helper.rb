# Etapa 2.4: what a cost marked "*" is missing, per part and reason, with the
# numbers it touches — so the "*" says what to fix (asked 09/10/2026).
module ValoresHelper
  MOTIVOS_DA_FALTA = {
    sem_corte: "no organized corte serves it — the arte's file can't be tied to the number",
    sem_arquivo: "no production file of this size in the arte",
    sem_lado: "the file of one side is missing",
    sem_medida: "the file has no size on the paper yet (DPI, or still processing)"
  }.freeze

  # Usage: faltas_do_custo(custos) # => ["Reforço (29, 30): no organized corte serves it — …"]
  def faltas_do_custo(custos)
    numeros = Hash.new { |hash, chave| hash[chave] = [] }
    custos.compact.each { |custo| custo.faltas.each { |falta| numeros[[ falta.peca&.nome || "Sem peça", falta.motivo ]] << custo.numero } }
    numeros.map { |(peca, motivo), lista| "#{peca} (#{lista.uniq.join(", ")}): #{MOTIVOS_DA_FALTA.fetch(motivo, motivo.to_s)}" }
  end
end
