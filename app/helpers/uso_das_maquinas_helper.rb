# What a machine measured and uses, as the Máquinas list, the machine's page
# and Ritmos say it (Máquinas 4/5b, canvas "Máquinas", 10–12). The lines
# come from UsoDasMaquinas.
module UsoDasMaquinasHelper
  # A fixed machine uses its informada: the canvas says "informada", the
  # list adds the "fixada" badge.
  ORIGENS_DO_USO = { medida: "medida", fixada: "informada", da_etapa: "da etapa", informada: "informada" }.freeze
  PLURAIS_DO_USO = { "medida" => "medidas", "informada" => "informadas", "da etapa" => "da etapa" }.freeze

  # Usage: ritmo_da_maquina(36.0, trabalho) # => "36 m/h"; a cutting machine's "62%"
  def ritmo_da_maquina(valor, trabalho)
    trabalho.corte_por_parametros? ? percentual_br(valor) : "#{numero_br(valor)} #{trabalho.tipo_de_trabalho.unidade}"
  end

  # Usage: medida_da_maquina(linha) # => "36 m/h · 6 turnos", "aproveitamento 62% · 7 turnos" or "faltam 3 turnos"
  def medida_da_maquina(linha)
    return "faltam #{pluralize(linha.faltam, "turno", plural: "turnos")}" unless linha.medida

    "#{"aproveitamento " if linha.trabalho.corte_por_parametros?}#{ritmo_da_maquina(linha.medida.valor, linha.trabalho)} · #{linha.medida.turnos} turnos"
  end

  # One per trabalho; two stages taking different ones are each named.
  # Usage: em_uso_da_maquina(linha) # => "medida · 36 m/h"; "Calçado da etapa 82 m/h · Tecido informada 100 m/h"
  def em_uso_da_maquina(linha)
    textos = linha.usos.map { |uso| "#{ORIGENS_DO_USO[uso.em_uso.origem]} · #{ritmo_da_maquina(uso.em_uso.valor, linha.trabalho)}" }
    return textos.first if textos.uniq.size == 1

    linha.usos.zip(textos).map { |uso, texto| "#{rotulo_da_etapa(uso.ritmo, linha.usos.map(&:ritmo))} #{texto.sub(" · ", " ")}" }.join(" · ")
  end

  # Ritmos' Medido for a stage with machines: their own, "1 de 2 máquinas".
  # Usage: medido_das_maquinas(ritmo, uso) # => "84 m/h · 1 de 2 máquinas"; the Corte's "62% e 70% · 2 de 2 máquinas"
  def medido_das_maquinas(ritmo, uso)
    medidas = uso.medidas_da_etapa(ritmo)
    quantas = "#{medidas.size} de #{pluralize(ritmo.maquinas.size, "máquina", plural: "máquinas")}"
    return quantas if medidas.empty?
    return "#{medidas.map { |medida| percentual_br(medida.valor) }.to_sentence(two_words_connector: " e ", last_word_connector: " e ")} · #{quantas}" if ritmo.maquina_de_corte?

    "#{numero_br(medidas.sum(&:valor))} #{ritmo.unidade} · #{quantas}"
  end

  # Usage: fix_das_maquinas(ritmo) # => "nas máquinas" or "fixado em 1 de 2 máquinas"
  def fix_das_maquinas(ritmo)
    fixadas = ritmo.maquinas.count(&:fixar_informado)
    fixadas.zero? ? "nas máquinas" : "fixado em #{fixadas} de #{pluralize(ritmo.maquinas.size, "máquina", plural: "máquinas")}"
  end

  # Ritmos' Em uso for a stage with machines: their sum, and of what.
  # Usage: em_uso_das_maquinas(ritmo, uso) # => ["166 m/h", "84 medida + 82 da etapa"]; ["77 m/h", "36 + 41 medidas"]
  #        the Corte's ["62% e 100%", "medida e informada"]; all alike, once: ["100%", "informada"]
  def em_uso_das_maquinas(ritmo, uso)
    usos = uso.da_etapa(ritmo)
    origens = usos.map { |feito| ORIGENS_DO_USO[feito.em_uso.origem] }
    return aproveitamentos_em_uso(usos, origens) if ritmo.maquina_de_corte?

    [ "#{numero_br(usos.sum { |feito| feito.em_uso.valor })} #{ritmo.unidade}", composicao_do_uso(usos, origens) ]
  end

  private

  # A cutting machine's aproveitamentos don't add up: each, or one when alike.
  def aproveitamentos_em_uso(usos, origens)
    valores = usos.map { |feito| percentual_br(feito.em_uso.valor) }
    return [ valores.first, origens.first ] if valores.zip(origens).uniq.size == 1

    [ valores, origens ].map { |lista| lista.to_sentence(two_words_connector: " e ", last_word_connector: " e ") }
  end

  def composicao_do_uso(usos, origens)
    return origens.first if usos.size == 1
    return "#{usos.map { |feito| numero_br(feito.em_uso.valor) }.join(" + ")} #{PLURAIS_DO_USO[origens.first]}" if origens.uniq.size == 1

    usos.zip(origens).map { |feito, origem| "#{numero_br(feito.em_uso.valor)} #{origem}" }.join(" + ")
  end
end
