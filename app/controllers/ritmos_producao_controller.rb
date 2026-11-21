# Each type × stage's rhythm per hour (Painel 2/4a, decided 05/11/2026): the
# dono types it, sees the one measured from the baixas (RitmoMedido) and may
# fix his own (Q5a). The calçado's Corte types the cutting machine's
# parameters instead (Painel 2/4a2). The dono's, like the rest of Parâmetros.
# Máquinas 1/5: a row whose trabalho has machines shows their sum, read
# only — it is changed in Máquinas; saving keeps what was typed there before.
class RitmosProducaoController < ApplicationController
  include NumeroDigitado
  exige_dono

  def edit
    @linhas = linhas_do_ritmo
    # Painel 2/4a2: cortes measured before the layers were count their whole line.
    @cortes_sem_camadas = visiveis(Arquivo).ativos.where(category: "corte").where(id: visiveis(Tamanho).where(linhas_por_cor: nil).select(:arquivo_id)).count
  end

  # Usage: PATCH /parametros/ritmos (ritmos[calcado][impressao][por_hora|fixar_informado], …;
  #        the Corte's machine: ritmos[calcado][corte][velocidade_mm_s|pinca_s|…])
  def update
    ritmos = linhas_do_ritmo.map { |linha| linha.ritmo.tap { |ritmo| ritmo.assign_attributes(digitado(linha)) } }
    invalidos = ritmos.reject(&:valid?)
    return redirect_to edit_parametros_ritmos_path, alert: invalidos.map { |r| "#{r.etapa_producao.nome} (#{Pedido::ROTULOS_DOS_TIPOS[r.tipo]}): #{r.errors.full_messages.to_sentence}" }.join("; ") if invalidos.any?

    # A row never typed stays unsaved.
    RitmoProducao.transaction { ritmos.select { |r| r.persisted? ? r.changed? : digitado?(r) }.each(&:save!) }
    redirect_to edit_parametros_ritmos_path, notice: "Production rhythm saved."
  end

  private

  CAMPOS_DIGITADOS = [ :por_hora, *RitmoProducao::MAQUINA_PADRAO.keys ].freeze

  # Blank = not set (per hour) or the default (the machine's). A row with
  # machines takes only the fix.
  def digitado(linha)
    dados = params.dig(:ritmos, linha.tipo, linha.etapa.chave) || {}
    fixar = { fixar_informado: dados[:fixar_informado] == "1" }
    return fixar if linha.ritmo.com_maquinas?

    CAMPOS_DIGITADOS.index_with { |campo| decimal_digitado(dados[campo]) }.merge(fixar)
  end

  def digitado?(ritmo)
    ritmo.fixar_informado || CAMPOS_DIGITADOS.any? { |campo| ritmo[campo] }
  end

  Linha = Struct.new(:tipo, :etapa, :ritmo, :medida, keyword_init: true)

  # One row per type × stage of config/etapas_producao.yml, saved or not,
  # each with its machines.
  def linhas_do_ritmo
    ritmos = RitmoProducao.da_fabrica(visiveis(RitmoProducao).to_a, trabalhos: visiveis(TrabalhoDaMaquina).ativos)
    medidas = RitmoMedido.call(CalendarioDeProducao.new(turnos: visiveis(Turno).ativos.to_a, excecoes: visiveis(ExcecaoCalendario).to_a), ritmos: ritmos.values)
    EtapasProducao.todas.flat_map do |tipo, etapas|
      etapas.map { |etapa| Linha.new(tipo: tipo, etapa: etapa, ritmo: ritmos.fetch([ tipo, etapa.chave ]), medida: medidas[[ tipo, etapa.chave ]]) }
    end
  end
end
