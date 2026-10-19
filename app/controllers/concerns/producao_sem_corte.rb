# The production page of a pedido without corte — the DTF's (Etapa 2.6b2)
# and the tecido's (2.7c, decided 19/10/2026): one page for its stages, a
# line per item (or etiqueta × size) with its baixa, and each Impressão
# line's file for the RIP, alone or every one in a .zip — once confirmed.
# The file may be a copy made in the background (the DTF's turned one, the
# tecido's compacted one): "preparando…" while queued.
#
# The includer gives `tipo_da_producao` ("dtf"), `rip_da(linha)` (an object
# with estado, caminho, nome and preparar!), `caminho_da_producao(etapa)`
# and `aviso_preparando(quantos)`.
module ProducaoSemCorte
  extend ActiveSupport::Concern

  included do
    exige :pedidos, :ver, only: :show
    exige_acao :baixar_producao, only: %i[arquivo arquivos preparados]
    before_action :set_pedido
    before_action :recusar_antes_da_confirmacao, only: %i[arquivo arquivos]
  end

  def show
    @etapa = EtapasProducao.etapa(@pedido.tipo, params[:etapa], pedido: @pedido)
    @linhas = LinhasDeProducao.call(@pedido, @etapa)
    @situacoes = RegistrarBaixaService.situacao(@pedido, @etapa.chave)
    @rips = @linhas.to_h { |linha| [ linha.chave, rip_da(linha) ] }
    @rips.each_value(&:preparar!) if @etapa.chave == "impressao" && helpers.pode_acao?(:baixar_producao) && @pedido.saiu_do_rascunho?
  rescue EtapasProducao::Invalida
    head :not_found
  end

  def arquivo
    linha = linhas_da_impressao.find { |l| l.chave == params[:linha].to_s }
    return head :not_found unless linha

    rip = rip_da(linha)
    return head :not_found if rip.estado == :pronto && rip.caminho.nil?
    return redirect_to caminho_da_producao("impressao"), alert: "#{aviso_preparando(1)} (#{rip.nome})." unless rip.caminho

    send_file rip.caminho, disposition: "attachment", filename: rip.nome
  end

  # Every line's file in one .zip, written to disk (artes go up to 1 GB).
  def arquivos
    rips = linhas_da_impressao.map { |linha| rip_da(linha) }
    preparando = rips.count { |rip| rip.estado == :preparando }
    return redirect_to caminho_da_producao("impressao"), alert: "#{aviso_preparando(preparando)}." if preparando.positive?

    destino = ZipsTemporarios.novo_caminho
    ZipDeArquivos.gravar(entradas(rips.select(&:caminho)), destino)
    send_file destino, type: "application/zip", disposition: "attachment", filename: "Impressao #{@pedido.uuid.first(8)}.zip"
  end

  # For the page's polling (processamento controller): final once every
  # copy is ready.
  def preparados
    render json: { final: linhas_da_impressao.none? { |linha| rip_da(linha).estado == :preparando } }
  end

  private

  def set_pedido
    @pedido = visiveis(Pedido).where(tipo: tipo_da_producao).por_uuid!(params[:uuid])
  end

  # A draft still changes: its files go to the RIP once confirmed.
  def recusar_antes_da_confirmacao
    return if @pedido.saiu_do_rascunho?

    redirect_to caminho_da_producao("impressao"), alert: "This pedido is #{@pedido.status}: its files go to the RIP once it is confirmed."
  end

  def linhas_da_impressao
    LinhasDeProducao.call(@pedido, EtapasProducao.etapa(@pedido.tipo, "impressao", pedido: @pedido))
  end

  # Names repeat only if two lines share one; numbered then.
  def entradas(rips)
    rips.each_with_object({}) do |rip, entradas|
      nome = rip.nome
      nome = "#{File.basename(nome, ".*")} (#{entradas.size + 1})#{File.extname(nome)}" if entradas.key?(nome)
      entradas[nome] = rip.caminho
    end
  end
end
