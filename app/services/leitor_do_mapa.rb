# Reads config/mapa.yml into MapaDoSistema's structs (Primeiros passos 1/6)
# and refuses what would break quietly later: a part in an unknown block, a
# link (precisa, alimenta, contagem.parte) to a part that doesn't exist, a
# page or an action target with no route, an unknown kind of action or of
# who fills it, a contagem without its counter. Each error names the part
# and what was expected; all of them at once.
#
# Usage: LeitorDoMapa.new(YAML.safe_load_file("config/mapa.yml")).call # => { blocos:, partes:, contagens: }
class LeitorDoMapa
  M = MapaDoSistema

  def initialize(conteudo)
    @conteudo = conteudo
    @erros = []
  end

  def call
    blocos = @conteudo.fetch("blocos").to_h { |id, b| [ id, M::Bloco.new(id: id, nome: b.fetch("nome"), cor: b.fetch("cor")) ] }
    partes = @conteudo.fetch("partes").to_h { |id, p| [ id, parte(id, p) ] }
    contagens = @conteudo.fetch("contagens").to_h { |id, c| [ id, M::Contagem.new(id: id, **c.slice("parte", "rotulo", "nenhum", "algum").symbolize_keys) ] }
    validar(blocos, partes, contagens)
    raise M::Invalido, "config/mapa.yml: #{@erros.join("; ")}" if @erros.any?

    { blocos: blocos, partes: partes, contagens: contagens }
  end

  private

  def parte(id, dados)
    M::Parte.new(id: id, nome: dados.fetch("nome"), bloco: dados.fetch("bloco"), pagina: dados["pagina"], icone: dados.fetch("icone"),
                 precisa: Array(dados["precisa"]), alimenta: Array(dados["alimenta"]), preenche: dados.fetch("preenche"), vazio: vazio(dados["vazio"]))
  end

  def vazio(dados)
    return unless dados

    acao = dados["acao"] && M::Acao.new(**dados["acao"].slice("rotulo", "tipo", "alvo", "permissao").symbolize_keys)
    M::Vazio.new(titulo: dados.fetch("titulo"), texto: dados.fetch("texto"), acao: acao, falta: Array(dados["falta"]), depois: dados["depois"] == true)
  end

  def validar(blocos, partes, contagens)
    partes.each_value do |parte|
      erro(parte, "block #{parte.bloco.inspect} is not one of #{blocos.keys.join(", ")}") unless blocos.key?(parte.bloco)
      erro(parte, "preenche #{parte.preenche.inspect} is not one of #{M::PREENCHE.join(", ")}") unless M::PREENCHE.include?(parte.preenche)
      (parte.precisa + parte.alimenta).reject { |outra| partes.key?(outra) }.each { |outra| erro(parte, "links to #{outra.inspect}, not a part") }
      erro(parte, "page #{parte.pagina.inspect} has no route") if parte.pagina && !rota?(parte.pagina)
      validar_vazio(parte, contagens) if parte.vazio
    end
    contagens.each_value { |contagem| validar_contagem(contagem, partes) }
  end

  def validar_vazio(parte, contagens)
    parte.vazio.falta.reject { |chave| contagens.key?(chave) }.each { |chave| erro(parte, "falta #{chave.inspect} is not a contagem") }
    acao = parte.vazio.acao
    return unless acao

    erro(parte, "action kind #{acao.tipo.inspect} is not one of #{M::TIPOS_DE_ACAO.join(", ")}") unless M::TIPOS_DE_ACAO.include?(acao.tipo)
    erro(parte, "action target #{acao.alvo.inspect} has no route") if %w[link post].include?(acao.tipo) && !rota?(acao.alvo.to_s)
  end

  def validar_contagem(contagem, partes)
    @erros << "contagem #{contagem.id}: part #{contagem.parte.inspect} doesn't exist" unless partes.key?(contagem.parte)
    @erros << "contagem #{contagem.id}: no counter in MapaDoSistema::CONTADORES" unless M::CONTADORES.key?(contagem.id)
  end

  def rota?(nome)
    Rails.application.routes.url_helpers.respond_to?("#{nome}_path")
  end

  def erro(parte, texto)
    @erros << "#{parte.id}: #{texto}"
  end
end
