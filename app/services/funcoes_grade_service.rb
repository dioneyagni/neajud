# Saves the Funções page grid (Etapa 0.5, 2/4): every função's name, level per
# área and special actions, all or nothing. The Dono função is never touched.
#
# Usage: erros = FuncoesGradeService.call(params[:funcoes]) # => [] when saved
#   params: { "<funcao uuid>" => { "nome" => "Corte", "niveis" => { "pedidos" => "1" }, "acoes" => ["baixar_producao"] } }
class FuncoesGradeService
  def self.call(grade)
    new(grade).call
  end

  def initialize(grade)
    @grade = grade.to_h
  end

  def call
    funcoes = Funcao.ativos.where(dono: false, uuid: @grade.keys).to_a
    funcoes.each { |funcao| funcao.assign_attributes(atributos(@grade[funcao.uuid])) }
    erros = funcoes.reject(&:valid?).flat_map { |funcao| funcao.errors.full_messages.map { |m| "#{funcao.nome_was}: #{m}" } }
    Funcao.transaction { funcoes.each(&:save!) } if erros.empty?
    erros
  end

  private

  def atributos(linha)
    linha = linha.to_h
    niveis = linha.fetch("niveis", {}).to_h.transform_values { |nivel| Integer(nivel, exception: false) || nivel }
    { nome: linha["nome"].to_s.strip, niveis: niveis, acoes: Array(linha["acoes"]).compact_blank }
  end
end
