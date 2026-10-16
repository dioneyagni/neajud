# A DTF pedido's production (Etapa 2.6b2, decided 15/10/2026): one page for
# its Impressão and Corte (the Corte only when delivered cut, D3), a line
# per etiqueta × size (D1) with its baixa, and each line's file for the RIP
# (D4: turned 90° when the fit turned it, the units in the name) — alone or
# every one in a .zip.
#
# Usage: GET /pedidos/:uuid/dtf/producao/impressao
#        GET /pedidos/:uuid/dtf/arquivo?linha=<key>
#        GET /pedidos/:uuid/dtf/arquivos (.zip)
#        GET /pedidos/:uuid/dtf/girados (JSON: are the turned copies ready?)
class ProducaoDtfController < ApplicationController
  exige :pedidos, :ver, only: :show
  exige_acao :baixar_producao, only: %i[arquivo arquivos girados]
  before_action :set_pedido
  before_action :recusar_antes_da_confirmacao, only: %i[arquivo arquivos]

  def show
    @etapa = EtapasProducao.etapa(@pedido.tipo, params[:etapa], pedido: @pedido)
    @linhas = LinhasDeProducao.call(@pedido, @etapa)
    @situacoes = RegistrarBaixaService.situacao(@pedido, @etapa.chave)
    @rips = @linhas.to_h { |linha| [ linha.chave, ArquivoDtfParaRip.new(linha) ] }
    @rips.each_value(&:preparar!) if @etapa.chave == "impressao" && helpers.pode_acao?(:baixar_producao) && @pedido.saiu_do_rascunho?
  rescue EtapasProducao::Invalida
    head :not_found
  end

  def arquivo
    linha = linhas_da_impressao.find { |l| l.chave == params[:linha].to_s }
    return head :not_found unless linha

    rip = ArquivoDtfParaRip.new(linha)
    return head :not_found if rip.estado == :pronto && rip.caminho.nil?
    return redirect_to producao_dtf_pedido_path(@pedido, etapa: "impressao"), alert: "O arquivo girado de #{rip.nome} ainda está sendo preparado." unless rip.caminho

    send_file rip.caminho, disposition: "attachment", filename: rip.nome
  end

  # Every line's file in one .zip, written to disk (artes go up to 1 GB).
  def arquivos
    rips = linhas_da_impressao.map { |linha| ArquivoDtfParaRip.new(linha) }
    preparando = rips.count { |rip| rip.estado == :preparando }
    return redirect_to producao_dtf_pedido_path(@pedido, etapa: "impressao"), alert: "#{preparando == 1 ? "1 arquivo girado ainda está" : "#{preparando} arquivos girados ainda estão"} sendo preparado(s)." if preparando.positive?

    destino = ZipsTemporarios.novo_caminho
    ZipDeArquivos.gravar(entradas(rips.select(&:caminho)), destino)
    send_file destino, type: "application/zip", disposition: "attachment", filename: "Impressao #{@pedido.uuid.first(8)}.zip"
  end

  # For the page's polling (processamento controller): final once every
  # turned copy is ready.
  def girados
    render json: { final: linhas_da_impressao.none? { |linha| ArquivoDtfParaRip.new(linha).estado == :preparando } }
  end

  private

  def set_pedido
    @pedido = visiveis(Pedido).where(tipo: "dtf").por_uuid!(params[:uuid])
  end

  # A draft's fit still changes: its files go to the RIP once confirmed.
  def recusar_antes_da_confirmacao
    return if @pedido.saiu_do_rascunho?

    redirect_to producao_dtf_pedido_path(@pedido, etapa: "impressao"), alert: "This pedido is #{@pedido.status}: its files go to the RIP once it is confirmed."
  end

  def linhas_da_impressao
    LinhasDeProducao.call(@pedido, EtapasProducao.etapa(@pedido.tipo, "impressao", pedido: @pedido))
  end

  # Names repeat only if two sizes share a label; numbered then.
  def entradas(rips)
    rips.each_with_object({}) do |rip, entradas|
      nome = rip.nome
      nome = "#{File.basename(nome, ".*")} (#{entradas.size + 1})#{File.extname(nome)}" if entradas.key?(nome)
      entradas[nome] = rip.caminho
    end
  end
end
