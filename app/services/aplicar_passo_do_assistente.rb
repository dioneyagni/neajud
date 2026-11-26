# Saves one step of the first-run wizard (Primeiros passos 2/6a, decided
# 20/11/2026, canvas "Primeiros passos", 7–11) as it is answered, so a
# wizard left halfway resumes where it stopped. It only adds and marks —
# never deletes: a função unchecked goes to the trash (one with people is
# kept, saying so), the turnos, machines and materials already there stay
# as they are (redoing the wizard shows them as done).
#
# dados: the step's params (strings, as the form sends them).
#
# Usage: r = AplicarPassoDoAssistente.call("produz", { "tipos" => %w[calcado dtf] }, empresa: Empresa.atual, autoria: autoria)
#        [r.ok?, r.erros, r.avisos] # => [true, [], []]
class AplicarPassoDoAssistente
  Resultado = Struct.new(:erros, :avisos, keyword_init: true) do
    def ok? = erros.empty?
  end

  TECIDOS = %w[corrida cor_lisa dublagem].freeze
  TECIDO_DE = %w[fabrica cliente ambos].freeze

  def self.call(chave, dados, empresa:, autoria:)
    new(empresa, autoria).call(chave, dados.to_h.with_indifferent_access)
  end

  def initialize(empresa, autoria)
    @empresa, @autoria = empresa, autoria
    @erros, @avisos = [], []
  end

  def call(chave, dados)
    PassosDoAssistente.passo(chave)
    ActiveRecord::Base.transaction do
      public_send("aplicar_#{chave}", dados)
      raise ActiveRecord::Rollback if @erros.any?
    end
    Resultado.new(erros: @erros, avisos: @avisos)
  rescue ActiveRecord::RecordInvalid => e
    Resultado.new(erros: [ "#{e.record.class.model_name.human} #{e.record.try(:nome)}: #{e.record.errors.full_messages.to_sentence}".squish ], avisos: [])
  end

  # What the factory makes (Q1a) and, with a fabric marked, whose it is.
  def aplicar_produz(dados)
    tipos = Array(dados[:tipos]) & ConteudoDoAssistente.tipos.keys
    return @erros << "Marque pelo menos uma coisa que vocês produzem" if tipos.empty?

    tecido_de = dados[:tecido_de] if (tipos & TECIDOS).any? && TECIDO_DE.include?(dados[:tecido_de])
    @empresa.update!(tipos_produzidos: tipos, tecido_de: tecido_de)
  end

  # The default funções kept or sent to the trash (Q4a); the Cliente final
  # only when clients come into the system.
  def aplicar_quem(dados)
    marcadas = Array(dados[:funcoes])
    ConteudoDoAssistente.funcoes.each_key { |nome| manter_funcao(nome, marcadas.include?(nome)) }
    manter_funcao("Cliente final", dados[:clientes_entram] == "1")
  end

  # The turnos typed (Q5) — a name already there is kept as it is — and the
  # national holidays of the year, when the factory stops on them.
  def aplicar_horario(dados)
    Array(dados[:turnos]).each { |turno| criar_turno(turno) }
    confirmar_feriados(Date.current.year) if dados[:feriados] == "1"
  end

  # A machine per row, with one trabalho (Q6a); the others on its page later.
  def aplicar_maquinas(dados)
    Array(dados[:maquinas]).each { |linha| criar_maquina(linha) }
  end

  # The typical materials checked (Q3a), with their groups; the empresa's
  # papel padrão and filme do DTF when it has none.
  def aplicar_materiais(dados)
    escolhidos = ConteudoDoAssistente.materiais_de(@empresa.tipos_produzidos || ConteudoDoAssistente.tipos.keys).slice(*Array(dados[:materiais]))
    return if escolhidos.empty?

    nomes = escolhidos.values.map { |m| m[:grupo] }.uniq
    criados = CadastroDeMateriais.new(grupos: ConteudoDoAssistente.grupos.select { |g| nomes.include?(g[:nome]) }, materiais: escolhidos).call[:materiais]
    definir_padroes(escolhidos, criados)
  end

  private

  def manter_funcao(nome, manter)
    funcao = Funcao.find_by(nome: nome)
    return unless funcao
    return funcao.restaurar!(**@autoria) if manter && funcao.excluido?
    return if manter || funcao.excluido?
    return @avisos << "#{nome} tem pessoas e continua; tire as pessoas dela em Usuários antes" if funcao.vinculos.exists?

    funcao.excluir!(**@autoria)
  end

  def criar_turno(dados)
    nome = dados[:nome].to_s.strip
    return if nome.blank? || Turno.ativos.exists?(nome: nome)

    turno = Turno.new(nome: nome, inicio: dados[:inicio], fim: dados[:fim], dias: Array(dados[:dias]).map(&:to_i))
    @erros.concat(turno.errors.full_messages.map { |erro| "#{nome}: #{erro}" }) unless turno.save
  end

  def confirmar_feriados(ano)
    FeriadosNacionais.do_ano(ano).reject(&:facultativo).each do |feriado|
      ExcecaoCalendario.find_or_create_by!(origem: "feriado", data: feriado.data) { |excecao| excecao.nome = feriado.nome }
    end
  end

  def criar_maquina(linha)
    nome = linha[:nome].to_s.squish
    return if nome.blank?

    maquina = Maquina.new
    dados = { nome: nome, trabalhos: { linha[:trabalho].to_s => { marcado: "1", por_hora: linha[:por_hora] } } }
    @erros.concat(maquina.errors.full_messages.map { |erro| "#{nome}: #{erro}" }) unless SalvarMaquina.new(maquina, dados, user: @autoria[:user]).call
  end

  def definir_padroes(escolhidos, criados)
    escolhidos.each do |chave, material|
      coluna = { "papel" => :papel_padrao, "filme_dtf" => :filme_dtf_padrao }[material[:padrao]]
      @empresa.update!(coluna => criados.fetch(chave)) if coluna && @empresa.public_send(coluna).nil?
    end
  end
end
