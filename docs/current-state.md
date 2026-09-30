# Estado atual do código

Auditoria da Etapa 0.2 do `docs/plano.md`, feita em 26/09/2026 sobre a `main` (`6229e2a`), sem alterar código. Cada item foi levantado no próprio código (models, rotas, grep), não de memória. Quando o código mudar, este documento envelhece: a fonte da verdade continua sendo o código.

## Visão geral

Rails 8.1 monolítico, SQLite, Hotwire (Turbo + Stimulus via Importmap), Solid Queue/Cache/Cable, ImageMagick, exiftool e scripts Node em `bin/` (UTIF.js e `dxf`).

| Item | Quantidade |
| --- | --- |
| Models | 23 (mais `FileCategory`, que é uma constante, sem tabela) |
| Controllers | 10 (mais `ApplicationController`) |
| Services | 15 |
| Jobs | 2 |
| Rotas | 90 |
| Controllers Stimulus | 23 |
| Scripts Node em `bin/` | 5 (`generate-preview.js`, `generate-dxf-preview.js`, `extract-tamanho-dxf.js`, `measure-dxf.js`, `detect-tamanhos.js`) |

Restos do nome antigo ("Stamp Tracker"): a pasta `storage/stamps/`, a classe CSS `.stamp-card` e o título "Tracker" da galeria.

## Models

Nomes do plano entre parênteses (ver "Code names vs docs/plano.md names" no AGENTS.md).

| Model | Papel | UUID | O que acontece com os dependentes ao apagar |
| --- | --- | --- | --- |
| `Arquivo` (Arte ou Corte) | Arquivo enviado; `category` "artes" ou "corte" | sim | versões, tamanhos, logs de tempo, vínculos com modelos e logs de vínculo: `destroy`; itens de pedido e peças de pedido: `restrict_with_error`; `before_destroy` impede apagar corte com arte ligada a um tamanho dele |
| `ArquivoVersion` | Versão do arquivo (original + prévia) | sim | metadados de imagem e camadas de corte: `destroy` |
| `ArquivoImageMetadata` | Colorspace, spots, ICC, dimensões | não | — |
| `ArquivoTimeLog` | Histórico de mudança de tempo | sim | — |
| `ArquivoVinculoLog` | Histórico de vínculo de arte a modelo/peça | não | — |
| `ArquivoModelo` | Corte ↔ modelos em que é usado | não | — |
| `CutLayer` | Camada do DXF (corte, furo, gravação ou ignorar) com medidas | não | — |
| `Tamanho` | Tamanho dentro de um corte ("30"), com medidas e prévia | não | — (tem `default_scope { order(:position) }`, só para ordenar) |
| `Molde` (Molde) | Molde físico | não | arquivos e modelos: `nullify`; `molde_pecas`: `delete_all` |
| `Peca` (Parte) | Parte do produto: lateral, língua… | não | arquivos, peças de pedido e logs: `nullify`; `molde_pecas`: `delete_all` |
| `MoldePeca` | Molde ↔ peças | não | — |
| `Modelo` (Referência) | Referência comercial, sempre de um cliente | não | arquivos e logs: `nullify`; `arquivo_modelos` e `modelo_pecas`: `destroy` |
| `ModeloPeca` | Peças configuradas do modelo (`needs_cut`) | não | — |
| `Client` | Cliente | não | modelos e movimentos de estoque: `destroy`; arquivos: `nullify`; pedidos: `restrict_with_error` |
| `Pedido` | Pedido: `rascunho`, `confirmado`, `cancelado` | sim | itens: `destroy`; logs de vínculo: `nullify` |
| `ItemPedido` | Item do pedido (uma arte + material) | sim | grade e peças do item: `destroy` |
| `ItemPedidoGrade` | Quantidade por tamanho do item | não | — |
| `ItemPedidoPeca` | Peça do modelo no item (incluída/excluída/pendente) | não | — |
| `MateriaPrima` | Material: grupo × cor × largura × gramatura | não | movimentos: `restrict_with_error`; itens de pedido: `nullify` |
| `GrupoMaterial`, `CorMaterial` | Cadastros do material | não | matérias-primas: `restrict_with_error` |
| `MovimentoEstoque` | Entrada/saída de material por cliente | não | — |
| `Ban` | IP bloqueado | sim | — |

## Controllers e rotas

| Controller | Actions | Rotas | Identificador na URL |
| --- | --- | --- | --- |
| `ArquivosController` (363 linhas) | galeria, upload, versões, prévia, download, organização do DXF, camadas, cliente/modelo/tamanho/tipo de corte, composição, `destroy`, `batch_destroy` | 21 | `:id` com o UUID (`find_by!(uuid:)`) |
| `PedidosController` | CRUD, adicionar/remover/atualizar item, marcar peça, produção, confirmar, resumo | 13 | `:uuid` |
| `PedidoPecasController` | escolher arte, vincular arte, enviar arte (peça pendente) | 3 | `:pedido_uuid` + id inteiro da peça |
| `MoldesController` | CRUD, peças, busca | 10 | id inteiro |
| `ModelosController` | CRUD, configuração de peças, busca | 9 | id inteiro |
| `PecasController` | CRUD, busca, cascata | 9 | id inteiro |
| `MateriaisController` | materiais, grupos, cores, busca | 8 | — |
| `ClientsController` | CRUD, busca | 7 | id inteiro |
| `MovimentosController` | lista e cria movimentos | 3 | — |
| `TamanhosController` | download do DXF do tamanho, cascata | 2 | id inteiro |

`ApplicationController` só carrega o contador do pedido atual e trata `RecordNotFound`.

## Services e jobs

| Service | Função |
| --- | --- |
| `ArquivoUploadService` | Upload: metadados, limite de 1 GB, tipo pelo conteúdo, versão 1, processamento |
| `FileValidator` | Formato real do arquivo via `identify -ping` |
| `DxfOrganizationService` | Separa o DXF em tamanhos e gera as prévias de cada um |
| `DxfMeasurementService` | Medidas das camadas do DXF |
| `CutLayerConfigurationService` | Reconfigura as camadas de corte |
| `TamanhoReplacementService` | Substitui os tamanhos de um corte |
| `MoldMatchService` | Compara o contorno da arte com os moldes para achar o tamanho |
| `TamanhoAutoAssignService` | Escolhe o tamanho da arte ao definir o modelo |
| `ModeloComposicaoService` | Peças do modelo para o item de pedido |
| `ArteCandidatasService` | Artes que podem completar uma peça pendente |
| `VincularArteService` | Vincula a arte ao modelo e peça, registra, preenche pendências |
| `ProducaoPedidoService` | Produção do pedido: peça + corte × tamanho, com o DXF de cada tamanho |
| `PedidoBloqueiosService` | O que impede confirmar o pedido |
| `ArquivoBatchDestroyService` | Exclusão em lote de arquivos |
| `UploadTimeEstimator` | Tempo estimado de trabalho por arquivo de um lote |

| Job | Função | Como roda |
| --- | --- | --- |
| `ArquivoProcessingJob` | Formato, spots, metadados, prévia, camadas, medidas e organização do DXF | `perform_now`, dentro do request (ver abaixo) |
| `AbuseDetectionJob` | Bloqueia o IP por 1 hora após 3 arquivos ≥ 500 MB | `perform_later` |

Adaptador da fila: `solid_queue` em produção, `inline` em teste; em desenvolvimento não está configurado (padrão do Rails).

## Autenticação

**Não existe.** Não há usuários, login, sessões de usuário nem perfis. "Quem fez" é o IP do request (`changed_by` em `ArquivoTimeLog` e `ArquivoVinculoLog`). A sessão só guarda o pedido em rascunho atual.

Proteções que existem:

- `BanMiddleware` (`lib/ban_middleware.rb`) responde 403 a IPs em `Ban.active`.
- `Rack::Attack`: 30 uploads (`POST /arquivos`) e 60 `update_time` por IP por minuto.
- Upload: 1 GB pelo tamanho real, tipo identificado pelo conteúdo (`FileValidator`); abuso gera `Ban` via `AbuseDetectionJob`.

Alvo: Etapa 0.5 (pessoa, vínculo e perfis) e Etapa 7.1 (login na nuvem).

## UUID por entidade

> **Resolvido na Etapa 1.1 (1/2), 30/09/2026:** toda entidade tem `uuid`, e só ele sai do servidor (ver "Public identifiers are uuids" no AGENTS.md). Ficaram sem: as tabelas de ligação (`arquivo_modelos`, `molde_pecas`), `sessions`, `arquivo_image_metadata` e `itens_pedido_grade`. O retrato abaixo é o de 26/09/2026.

- **Com `uuid`:** `arquivos`, `arquivo_versions`, `arquivo_time_logs`, `pedidos`, `itens_pedido`, `bans`.
- **Sem `uuid`:** `arquivo_image_metadata`, `arquivo_modelos`, `arquivo_vinculo_logs`, `clients`, `cor_materiais`, `cut_layers`, `grupo_materiais`, `item_pedido_pecas`, `itens_pedido_grade`, `materia_primas`, `modelo_pecas`, `modelos`, `molde_pecas`, `moldes`, `movimento_estoques`, `pecas`, `tamanhos`.
- Nas URLs, só arquivos e pedidos usam o UUID; moldes, modelos, peças, clientes, tamanhos e as peças de pedido usam o id inteiro.

Alvo: Etapa 1.1 (UUID em todas as entidades, junto com a renomeação).

## Exclusões físicas

**Atualizado em 26/09/2026 (Etapa 0.4):** as exclusões pelo usuário da tabela abaixo (menos `remover_item` e `remove_modelo`) agora vão para a lixeira (`deleted_at`, restauração em `/lixeira`), e nada mais é apagado do disco. A tabela registra como era na auditoria.

Na auditoria, toda exclusão apagava de verdade. Não havia `deleted_at` nem restauração.

| Onde | O que apaga |
| --- | --- |
| `DELETE /arquivos/:id` | o arquivo, suas versões, tamanhos e logs, e a pasta `storage/stamps/<uuid>` |
| `DELETE /arquivos/batch_destroy` | o mesmo, em lote (`ArquivoBatchDestroyService`) |
| `DELETE /clients/:id` | o cliente, **seus modelos e movimentos de estoque** (bloqueia se tiver pedidos) |
| `DELETE /modelos/:id` | o modelo, vínculos com cortes e peças configuradas |
| `DELETE /moldes/:id` | o molde e os vínculos com peças |
| `DELETE /pecas/:id` | a peça e os vínculos com moldes |
| `DELETE /pedidos/:uuid` | o pedido e seus itens |
| `DELETE /pedidos/:uuid/remover_item` | o item, sua grade e peças |
| `DELETE /arquivos/:id/remove_modelo` | só o vínculo corte ↔ modelo |

Substituições internas (não são exclusão pelo usuário, mas também apagam linhas): tamanhos ao reorganizar o DXF (`DxfOrganizationService`, `TamanhoReplacementService`), camadas de corte ao reprocessar ou reconfigurar, `modelo_pecas` ao sincronizar com o molde, linhas de grade zeradas.

Alvo: Etapa 0.4 (exclusão lógica) — concluída; as substituições internas continuam físicas, pois são dados calculados.

## Onde o processamento de arquivos roda

- **Atualizado em 26/09/2026 (Etapa 0.3):** o `ArquivoProcessingJob` do upload (galeria, nova versão e "Enviar arquivo") agora é enfileirado no Solid Queue; a tela mostra "Na fila"/"Processando" e se atualiza sozinha (ver "Background processing" no AGENTS.md). Antes rodava com `perform_now` dentro do request.
- **Também no request, trabalho pesado sobre arquivos já processados:**
  - `MoldMatchService` (ImageMagick) no `update_modelo`, via `TamanhoAutoAssignService`;
  - `DxfOrganizationService` (gera PNG das prévias dos tamanhos) na organização do DXF;
  - `TamanhosController#download` roda `bin/extract-tamanho-dxf.js` no primeiro download de cada tamanho (depois usa o arquivo em `tmp/tamanho_extracts/`).
- **Em fila:** o `ArquivoProcessingJob` (desde a Etapa 0.3) e o `AbuseDetectionJob`.

Alvo para o que ainda roda no request: Etapa 0.6.

## Específico de sublimação × estrutura genérica

| Genérico (catálogo e produção de qualquer processo) | Específico de sublimação / estamparia |
| --- | --- |
| Molde, Peça (Parte), Modelo (Referência) e seus vínculos | Pipeline de prévia da arte: spots, CMYK/RGB, perfis ICC, UTIF.js (`ArquivoProcessingJob`) |
| Corte em DXF: organização em tamanhos, camadas (corte, furo, gravação), medidas, download por tamanho | `tipo_corte` do corte (`corte_estampa` × `apenas_corte`: se a peça recebe estampa) |
| Pedido: itens, grade, peças do modelo, bloqueios de confirmação, produção por peça × tamanho | `MoldMatchService`: encaixar a arte no contorno do molde para achar o tamanho |
| Clientes | Artes como arquivos de impressão (`FileCategory` "artes": tif, psd, ai, eps, cdr, pdf) |
| Tempo por arquivo (estimado e anotado) | Materiais: grupo × cor × largura × gramatura e estoque por cliente (tecido/malha para sublimar) |

Alvo: Etapa 6.4 (camada de processo), que separa o que é de cada processo.

## Outras observações

- `FileCategory` declara `preview: false` para "corte", mas o job gera a prévia SVG de todo DXF pela extensão.
- Existem regras no model que só valem para cortes organizados (`peca_modelo_uniqueness_for_organized_corte`) e um bloqueio de exclusão de corte com arte ligada (`prevent_destroy_with_linked_arquivos`).
- A "Produção" do pedido acha o DXF pelo **nome** do tamanho da grade; a Etapa 1.2 troca isso por cortes que declaram os tamanhos que atendem.
