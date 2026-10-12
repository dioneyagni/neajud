# The upload's grouping (Etapa 1.2, 2/3 parte 3): the browser sends only the
# chosen files' names and weights; the answer says which go together, their
# part, size and suggested piloto, and existing artes they may belong to.
class AgrupamentosUploadController < ApplicationController
  before_action { exigir!(pode?(:artes, :editar) || pode?(:catalogo, :editar), "artes or catalogo: editar") }

  # Usage: POST /arquivos/agrupamento (arquivos: [{ nome:, bytes: }]) → JSON
  def create
    arquivos = Array(params[:arquivos]).map { |a| { nome: a[:nome].to_s, bytes: a[:bytes].to_i } }
    resultado = AgrupamentoDoUpload.call(arquivos, pecas: visiveis(Peca).ativos.to_a, candidatas: visiveis(Arquivo))
    # tipos: each group's kind of work in the conference (Etapa 2.5a).
    render json: { conferir: resultado[:conferir], pecas: pecas_json, grupos: resultado[:grupos].map { |g| grupo_json(g) },
                   tipos: TipoDaArte::ROTULOS.map { |tipo, rotulo| tipo_na_conferencia(tipo, rotulo) } }
  end

  private

  # Etapa 2.5c: which fields the conference shows for a group of this kind.
  def tipo_na_conferencia(tipo, rotulo)
    arte = Arte.new(tipo: tipo)
    { tipo: tipo, rotulo: rotulo, usa_pecas: arte.usa_pecas?, usa_tamanhos: arte.usa_tamanhos? }
  end

  def pecas_json
    visiveis(Peca).ativos.order(:nome).map { |peca| { uuid: peca.uuid, nome: peca.nome } }
  end

  def grupo_json(grupo)
    {
      titulo: grupo.titulo,
      arquivos: grupo.arquivos.map { |a| { indice: a.indice, parte_uuid: a.parte&.uuid, tamanho: a.tamanho, lado: a.lado, piloto: a.piloto } },
      existentes: grupo.existentes.map { |arquivo| existente_json(arquivo) }
    }
  end

  def existente_json(arquivo)
    {
      arte_uuid: arquivo.arte.uuid, titulo: arquivo.arte.titulo, url: arquivo_path(arquivo),
      resumo: helpers.resumo_da_arte(arquivo) || arquivo.filename,
      preview: (preview_arquivo_path(arquivo) if arquivo.preview_file.present?)
    }
  end
end
