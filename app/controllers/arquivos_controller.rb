class ArquivosController < ApplicationController
  before_action :set_arquivo, only: %i[show busca_tamanho preparacao_tamanhos update_time update_client update_molde update_tamanho update_tipo_corte add_molde remove_molde preview composicao processamento download destroy upload_version approve_version version_preview configure_layers organize]
  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  # Permissions (Etapa 0.5): an arquivo is Artes or, if a corte, Catálogo
  # (Arquivo#area_de_acesso), so most checks need @arquivo loaded first.
  before_action(only: :index) { exigir!(pode?(:artes, :ver) || pode?(:catalogo, :ver), "artes or catalogo: ver") }
  before_action(only: :create) { exigir!(pode?(:artes, :editar) || pode?(:catalogo, :editar), "artes or catalogo: editar") }
  before_action(only: :batch_destroy) { exigir!(pode?(:artes, :excluir) || pode?(:catalogo, :excluir), "artes or catalogo: excluir") }
  before_action(only: %i[show preview composicao processamento busca_tamanho preparacao_tamanhos version_preview]) { exigir_no_arquivo!(:ver) }
  before_action(only: %i[update_time update_client update_molde update_tamanho update_tipo_corte add_molde remove_molde
                         upload_version approve_version configure_layers organize]) { exigir_no_arquivo!(:editar) }
  before_action(only: :destroy) { exigir_no_arquivo!(:excluir) }
  exige_acao :baixar_producao, only: :download

  PER_PAGE_GRID = 12
  PER_PAGE_LIST = 50

  def index
    load_gallery
    @arquivo = Arquivo.new
  end

  def show
    @time_logs = @arquivo.arquivo_time_logs.order(created_at: :desc)
    @versions = @arquivo.arquivo_versions.order(version_number: :desc)
    @arquivo_version = ArquivoVersion.new
    @vinculo_logs = @arquivo.vinculo_logs.includes(:peca, :pedido)
  end

  def create
    @arquivo = Arquivo.new(arquivo_params)

    unless file_uploaded?
      @arquivo.errors.add(:original_file, "select a file to upload")
      load_gallery
      return render :index, status: :unprocessable_content
    end

    estimate_time!(@arquivo) if params.dig(:arquivo, :batch_started_at).present?
    ArquivoUploadService.call(params[:arquivo][:original_file], remote_ip: request.remote_ip, arquivo: @arquivo)

    if @arquivo.persisted?
      redirect_to arquivos_path, notice: "Arquivo uploaded successfully. Processing started."
    else
      load_gallery
      render :index, status: :unprocessable_content
    end
  end

  def upload_version
    upload = params[:original_file]
    unless upload.respond_to?(:original_filename)
      return redirect_to @arquivo, alert: "Select a file to upload."
    end

    version = @arquivo.nova_versao!(nome_original: upload.original_filename, mime_type: upload.content_type) do |nova|
      next false if ArquivoUploadService.erro_de_tipo(nova.extension, upload)

      nova.store_original!(upload)
    end
    return redirect_to @arquivo, alert: "Invalid file type." unless version

    redirect_to @arquivo, notice: "Version #{version.version_number} uploaded and processing."
  end

  def approve_version
    version = @arquivo.arquivo_versions.por_uuid!(params[:version_uuid])
    @arquivo.arquivo_versions.update_all(approved: false)
    version.update!(approved: true)
    @arquivo.update!(approved_version_id: version.id)
    redirect_to @arquivo, notice: "Version #{version.version_number} is now in use."
  end

  def configure_layers
    version = @arquivo.arquivo_versions.por_uuid!(params[:version_uuid])
    annotations = params[:layer_annotations]
    unless annotations.is_a?(ActionController::Parameters) || annotations.is_a?(Hash)
      return head :bad_request
    end

    CutLayerConfigurationService.call(version, annotations)
    redirect_to @arquivo, notice: "Layer configuration saved."
  end

  def add_molde
    molde = Molde.ativos.por_uuid!(params[:molde_uuid])
    if @arquivo.corte? && @arquivo.organized? && @arquivo.peca_id.present?
      conflict = Arquivo.conflicting_corte(peca_id: @arquivo.peca_id, molde: molde)
      if conflict && conflict.id != @arquivo.id
        flash.now[:alert] = "Peça \"#{@arquivo.peca.nome}\" já possui corte organizado para este molde."
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to @arquivo, alert: flash.now[:alert] }
        end
        return
      end
    end
    unless @arquivo.moldes.include?(molde)
      @arquivo.moldes << molde
    end
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @arquivo, notice: "Molde added." }
    end
  end

  def remove_molde
    molde = @arquivo.moldes.por_uuid!(params[:molde_uuid])
    @arquivo.moldes.delete(molde)
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @arquivo, notice: "Molde removed." }
    end
  end

  def update_client
    if @arquivo.update(client_uuid: params[:client_uuid])
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @arquivo, notice: "Client updated." }
      end
    else
      redirect_to @arquivo, alert: "Could not update client: #{@arquivo.errors.full_messages.to_sentence}"
    end
  end

  def update_molde
    updates = { molde_uuid: params[:molde_uuid] }
    updates[:modelo_uuid] = params[:modelo_uuid] if params[:modelo_uuid].present?
    updates[:peca_uuid] = params[:peca_uuid] if params[:peca_uuid].present?
    # Unlink (molde_uuid blank): also forget the modelo that came with it.
    updates[:modelo_id] = nil if params[:molde_uuid].blank? && !@arquivo.corte?
    # Referências belong to one molde (Etapa 1.1, 5/5): another molde's goes.
    updates[:referencia_id] = nil if params[:molde_uuid] != @arquivo.molde&.uuid

    if @arquivo.update(updates)
      @arquivo.reload
      @arquivo.descartar_tamanho_fora_do_molde!
      @arquivo.ajustar_referencia_e_nome!
      # Etapa 0.6: the search (up to 37 s) runs in the queue; the page shows
      # "Procurando tamanho…" and refreshes when it ends.
      @arquivo.buscar_tamanho_em_fila!
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @arquivo, notice: params[:molde_uuid].present? ? "Molde updated." : "Molde unlinked." }
      end
    else
      redirect_to @arquivo, alert: "Could not update molde: #{@arquivo.errors.full_messages.to_sentence}"
    end
  end

  # Polling safety nets (processamento_controller.js, "refresh" mode): the
  # page reloads once the queued task is over.
  # Usage: GET /arquivos/:uuid/busca_tamanho.json # => { "final": true }
  def busca_tamanho
    render json: { final: !@arquivo.buscando_tamanho? }
  end

  # Usage: GET /arquivos/:uuid/preparacao_tamanhos.json # => { "final": false }
  def preparacao_tamanhos
    render json: { final: !@arquivo.preparando_tamanhos? }
  end

  def update_tamanho
    if @arquivo.update(tamanho_uuid: params[:tamanho_uuid])
      @arquivo.reload
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @arquivo, notice: "Size updated." }
      end
    else
      redirect_to @arquivo, alert: "Could not update size: #{@arquivo.errors.full_messages.to_sentence}"
    end
  end

  def update_tipo_corte
    if @arquivo.update(tipo_corte: params[:tipo_corte])
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @arquivo, notice: "Cut type updated." }
      end
    else
      redirect_to @arquivo, alert: "Could not update cut type."
    end
  end

  def update_time
    previous_seconds = @arquivo.annotated_seconds || @arquivo.estimated_seconds
    new_seconds = parse_hmm(params[:annotated_seconds])

    if @arquivo.update(annotated_seconds: new_seconds)
      @arquivo.arquivo_time_logs.create!(
        previous_seconds: previous_seconds,
        new_seconds: @arquivo.annotated_seconds,
        **autoria
      )
      @time_logs = @arquivo.arquivo_time_logs.order(created_at: :desc)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @arquivo, notice: "Time updated." }
      end
    else
      redirect_to @arquivo, alert: "Could not update time."
    end
  end

  def preview
    path = @arquivo.preview_file
    raise ActionController::MissingFile unless path && File.exist?(path.to_s)

    mime = path.to_s.end_with?(".svg") ? "image/svg+xml" : "image/png"
    send_file path.to_s, type: mime, disposition: "inline"
  rescue ActionController::MissingFile, Errno::ENOENT
    head :not_found
  end

  # Pieces of this arte's molde (see MoldeComposicaoService), for the
  # "Adicionar ao Pedido" modal to list before the item is created.
  # Usage: GET /arquivos/:uuid/composicao → { pecas: [{ peca_nome:, arquivo_uuid:, … }] }
  def composicao
    slots = MoldeComposicaoService.call(@arquivo)
    render json: { pecas: slots.map { |slot| composicao_slot_json(slot) } }
  end

  # Processing state of the approved version, polled by the "processamento"
  # Stimulus controller while an arquivo is queued. Safety net for a broadcast
  # sent while the page was still (re)connecting to the cable — it never
  # arrives, and the card stayed on "Processando" (Etapa 0.3, seen in E2E).
  # Usage: GET /arquivos/:uuid/processamento.json → { status:, final: }
  #        GET /arquivos/:uuid/processamento (turbo-stream) → replaces the card
  def processamento
    respond_to do |format|
      format.json { render json: { status: @arquivo.status, final: !(@arquivo.pending? || @arquivo.processing?) } }
      format.turbo_stream { render turbo_stream: turbo_stream.replace(@arquivo, partial: "arquivos/card", locals: { arquivo: @arquivo }) }
    end
  end

  def version_preview
    version = @arquivo.arquivo_versions.por_uuid!(params[:version_uuid])
    raise ActionController::MissingFile if version.preview_file.blank?
    path = version.preview_file
    raise ActionController::MissingFile unless File.exist?(path)
    mime = path.end_with?(".svg") ? "image/svg+xml" : "image/png"
    send_file path, type: mime, disposition: "inline"
  rescue ActionController::MissingFile, Errno::ENOENT
    head :not_found
  end

  def download
    path = @arquivo.approved_original_path
    raise ActionController::MissingFile unless path && File.exist?(path.to_s)
    version = @arquivo.approved_version
    # An arte with a molde downloads under its full name (Etapa 1.1, 5/5).
    filename = "#{@arquivo.nome_completo(para_arquivo: true) || version.filename}.#{version.extension}"
    send_file path.to_s, type: version.mime_type, disposition: "attachment", filename: filename
  rescue ActionController::MissingFile, Errno::ENOENT
    head :not_found
  end

  def organize
    # Etapa 1.2 (1/3): the grade type and each size, read before saving.
    substituicao = TamanhoReplacementService.new(@arquivo, params[:tamanhos], tipo: params[:tipo_grade]) if params[:tamanhos].respond_to?(:values)
    return recusar_organizacao(substituicao.erro) if substituicao&.erro
    return recusar_organizacao("Esta peça já possui um corte organizado para este molde.") if peca_ocupada?
    return recusar_organizacao(@arquivo.errors.full_messages.join(", ")) unless @arquivo.update(atributos_da_organizacao)

    substituicao&.call

    # Etapa 0.6: the heavy part (re-detection, each size's DXF and preview)
    # runs in PreparacaoTamanhosJob; the page shows "Preparando os tamanhos…".
    if @arquivo.organize_error.present?
      @arquivo.preparar_tamanhos_em_fila!(redetectar: true)
    elsif @arquivo.tamanhos.any? && @arquivo.tamanhos.all? { |t| t.preview_file.blank? }
      @arquivo.preparar_tamanhos_em_fila!(redetectar: false)
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @arquivo, notice: "Mold organization saved." }
    end
  end

  def atributos_da_organizacao
    atributos = { organized: true }
    %i[modelo_uuid peca_uuid modelo_nome peca_nome].each { |campo| atributos[campo] = params[campo] if params[campo].present? }
    atributos[:tipo_grade] = params[:tipo_grade].presence if params.key?(:tipo_grade)
    atributos
  end
  private :atributos_da_organizacao

  def recusar_organizacao(mensagem)
    flash.now[:alert] = mensagem
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @arquivo, alert: mensagem }
    end
  end
  private :recusar_organizacao

  # Another organized corte of one of this corte's moldes already has the peça.
  def peca_ocupada?
    return false unless params[:peca_uuid].present? && @arquivo.corte?

    peca_id = Peca.por_uuid!(params[:peca_uuid]).id
    @arquivo.moldes.any? { |m| (c = Arquivo.conflicting_corte(peca_id: peca_id, molde: m)) && c.id != @arquivo.id }
  end
  private :peca_ocupada?

  # Etapa 0.4: goes to the trash; the row, its versions and the files in
  # storage/stamps/<uuid> stay, so pedidos that use it keep their previews
  # and it can be restored from /lixeira.
  def destroy
    @arquivo.excluir!(**autoria)
    redirect_to arquivos_path, notice: "Arquivo moved to the trash."
  end

  def batch_destroy
    ids = params[:ids]
    unless ids.is_a?(Array) && ids.any?
      return render json: { error: "No IDs provided" }, status: :unprocessable_content
    end

    permitidos, negados = ids.partition { |uuid| pode_excluir_arquivo?(uuid) }
    destroyed_uuids, errors = ArquivoBatchDestroyService.call(permitidos, **autoria)
    errors += negados.map { |uuid| { uuid: uuid, error: "no permission to delete it" } }

    render json: { destroyed: destroyed_uuids.size, errors: errors }
  end

  private

  def composicao_slot_json(slot)
    arte = slot.arquivo
    {
      peca_nome: slot.peca&.nome,
      arquivo_uuid: arte&.uuid,
      filename: arte&.filename,
      preview_url: arte&.preview_file.present? ? preview_arquivo_path(arte) : nil,
      pendente: arte.nil?,
      adicionada: arte == @arquivo
    }
  end

  def exigir_no_arquivo!(nivel)
    exigir!(pode?(@arquivo.area_de_acesso, nivel), "#{@arquivo.area_de_acesso}: #{nivel}")
  end

  # Unknown uuids pass through so the service reports them as not found.
  def pode_excluir_arquivo?(uuid)
    arquivo = Arquivo.find_by(uuid: uuid)
    arquivo.nil? || pode?(arquivo.area_de_acesso, :excluir)
  end

  def set_arquivo
    @arquivo = Arquivo.find_by!(uuid: params[:id])
  end

  STORAGE_BASE = ArquivoVersion::STORAGE_BASE

  def file_uploaded?
    upload = params[:arquivo][:original_file]
    upload.respond_to?(:tempfile) || upload.respond_to?(:original_filename)
  end

  def parse_hmm(value)
    return value.to_i unless value.to_s.include?(":")

    hours, minutes = value.to_s.split(":").map(&:to_i)
    (hours * 3600) + (minutes * 60)
  end

  def not_found
    render plain: "Not found", status: :not_found
  end

  def estimate_time!(arquivo)
    arquivo.estimated_seconds = UploadTimeEstimator.call(
      batch_started_at: Time.parse(params[:arquivo][:batch_started_at]),
      batch_size: params[:arquivo][:batch_size].to_i
    )
  end

  def arquivo_params
    params.require(:arquivo).permit(:filename, :extension, :mime_type)
  end

  def load_gallery
    @view = %w[grid list].include?(params[:view]) ? params[:view] : "grid"
    per_page = @view == "list" ? PER_PAGE_LIST : PER_PAGE_GRID
    @page = [ params[:page].to_i, 1 ].max

    # Etapa 1.2 (2/3): one card per arte (its first file), not one per file.
    base = Arquivo.ativos.where(category: Arquivo.categorias_visiveis(autorizacao)).principais_das_artes
                  .includes(:client, :tamanhos, approved_version: :image_metadata, molde: :modelo).order(created_at: :desc)
    @total = base.count
    @total_pages = (@total.to_f / per_page).ceil
    @page = @page.clamp(1, [ @total_pages, 1 ].max)
    @arquivos = base.offset((@page - 1) * per_page).limit(per_page)
  end
end
