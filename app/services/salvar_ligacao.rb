# Saves a ligação from its page (rede editável 2/2a, decided 10/11/2026):
# the groups only when it is new (Q4a), the lado, before or after, the usual
# ligantes and a situação's in their place, what is still to confirm — and
# a line in its histórico saying what changed (Q3a), "criou" for a new one.
# The ligantes are rewritten whole, in the page's order. Nothing changed,
# no line. origem "construcao": made from a construção's card (Dublagem
# 5b1b), and the histórico says so.
#
# dados: { grupo_a_uuid:, grupo_b_uuid:, lado:, dubla:, a_confirmar: [],
#          ligantes: [{ grupo_uuid:, micras: "25, 35" }],
#          situacoes: { "tecido_molha" => [{ grupo_uuid:, micras: }] } }
# grupos, situacoes: the visible scopes to look them up in.
#
# Usage: SalvarLigacao.new(ligacao, dados, grupos: visiveis(GrupoMaterial), situacoes: visiveis(SituacaoDublagem), user: Current.user).call # => true
class SalvarLigacao
  CRIACOES = { nil => "criou", "construcao" => "criou a partir da construção" }.freeze

  def initialize(ligacao, dados, grupos:, situacoes:, user:, origem: nil)
    @ligacao = ligacao
    @dados = dados.to_h.with_indifferent_access
    @grupos = grupos
    @situacoes = situacoes
    @user = user
    @criacao = CRIACOES.fetch(origem.presence) { raise ArgumentError, "origem #{origem.inspect} is not known; expected one of #{CRIACOES.keys.compact.join(", ")} or none" }
    @erros = []
  end

  # false with the reasons in ligacao.errors; nothing written.
  def call
    antes = @ligacao.resumo unless @ligacao.new_record?
    aplicar
    return false unless valida?

    LigacaoDublagem.transaction do
      @ligacao.save!
      texto = antes ? MudancasDaLigacao.new(antes, @ligacao.reload.resumo).texto : @criacao
      @ligacao.alteracoes.create!(texto: texto, user: @user) if texto.present?
    end
    true
  end

  private

  def aplicar
    aplicar_grupos if @ligacao.new_record?
    @ligacao.assign_attributes(lado: @dados[:lado].presence, dubla: @dados[:dubla], a_confirmar: Array(@dados[:a_confirmar]).compact_blank.uniq)
    @ligacao.ligantes.each(&:mark_for_destruction)
    linhas = linhas_dos_ligantes
    @erros << "escolha ao menos um ligante" if linhas.none? { |_, situacao| situacao.nil? }
    linhas.each.with_index(1) { |(linha, situacao), posicao| construir_ligante(linha, situacao, posicao) }
  end

  def aplicar_grupos
    @ligacao.grupo_a, @ligacao.grupo_b = %i[grupo_a_uuid grupo_b_uuid].map { |campo| @grupos.find_by(uuid: @dados[campo].presence) }
    @erros << "escolha os dois grupos" unless @ligacao.grupo_a && @ligacao.grupo_b
  end

  # [linha, SituacaoDublagem or nil], skipping the rows with no group.
  def linhas_dos_ligantes
    usuais = Array(@dados[:ligantes]).map { |linha| [ linha, nil ] }
    de_situacao = @dados.fetch(:situacoes, {}).to_h.flat_map do |chave, lista|
      situacao = @situacoes.find_by(chave: chave) || raise(ActiveRecord::RecordNotFound, "situação #{chave.inspect} not found; expected one of #{@situacoes.pluck(:chave).join(", ")}")
      Array(lista).map { |linha| [ linha, situacao ] }
    end
    (usuais + de_situacao).select { |linha, _| linha[:grupo_uuid].present? }
  end

  def construir_ligante(linha, situacao, posicao)
    grupo = @grupos.find_by!(uuid: linha[:grupo_uuid])
    micras = LiganteDaLigacao.micras_digitadas(linha[:micras])
    @erros << "micras #{linha[:micras].to_s.strip.inspect} de #{grupo.nome}: esperado vazio (qualquer), uma lista como 25, 35 ou um mínimo como 35 ou mais" unless micras
    ligante = @ligacao.ligantes.build(grupo_material: grupo, situacao_dublagem: situacao, posicao: posicao, **(micras || {}))
    ligante.texto_das_micras = linha[:micras]
  end

  def valida?
    @ligacao.valid?
    @erros.each { |erro| @ligacao.errors.add(:base, erro) }
    @ligacao.errors.empty?
  end
end
