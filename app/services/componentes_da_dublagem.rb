# What dubbing a meter of a construção takes from the stock (Dublagem 5a,
# decided 03/11/2026): 1 m of each layer, from the layer's owner (do_cliente
# is the construção's client, else the empresa), and 1 m of each ligação's
# ligante, the empresa's — the loss of each dublagem is for later (plano
# 09/10/2026). Dublagem 5b2b (Q2a): a cola, counted in kg, takes its
# consumption over the construção's width instead (MateriaPrima#por_metro_dublado);
# one without its consumption takes nothing. The same material and owner twice (Oxford over Oxford) is one
# component of 2 m per meter. A ligação without a ligante chosen takes
# nothing (sem_ligante says how many).
#
# Usage: componentes = ComponentesDaDublagem.new(construcao)
#        componentes.to_a # => [#<Componente materia_prima=Oxford client=nil por_metro=1>, …]
#        componentes.faltas(10, SaldosDeEstoque.call) # => [#<Componente … falta=4.0>]
class ComponentesDaDublagem
  include Enumerable

  Componente = Struct.new(:materia_prima, :client, :por_metro, :falta, keyword_init: true)

  def initialize(construcao)
    @construcao = construcao
  end

  def each(&)
    componentes.each(&)
  end

  def sem_ligante = @construcao.camadas_em_ordem.drop(1).count { |camada| camada.ligante.nil? }

  # The components whose balance doesn't cover the meters, with what is missing.
  def faltas(metros, saldos)
    filter_map do |componente|
      saldo = componente.client ? saldos.por_cliente(componente.materia_prima)[componente.client].to_f : saldos.empresa(componente.materia_prima)
      falta = (metros * componente.por_metro) - saldo
      componente.dup.tap { |c| c.falta = falta.round(3) } if falta.positive?
    end
  end

  private

  def componentes
    @componentes ||= partes.group_by { |material, client, _| [ material, client ] }.map do |(material, client), lista|
      Componente.new(materia_prima: material, client: client, por_metro: lista.sum(&:last))
    end
  end

  # [material, client, per meter] per layer and per ligante, top to bottom.
  def partes
    camadas = @construcao.camadas_em_ordem
    largura = @construcao.largura_mais_estreita_mm
    das_camadas = camadas.map { |camada| [ camada.materia_prima, (@construcao.client if camada.do_cliente), 1 ] }
    das_camadas + camadas.drop(1).filter_map { |camada| [ camada.ligante, nil, camada.ligante.por_metro_dublado(largura) || 0 ] if camada.ligante }
  end
end
