Rails.application.routes.draw do
  resource :session, only: %i[new create destroy]
  get "configuracao" => "configuracao#new", as: :configuracao
  post "configuracao" => "configuracao#create"
  resources :usuarios, only: %i[index new create edit update], param: :uuid do
    member do
      post :redefinir_senha
      post :desativar
      post :reativar
    end
  end
  resource :senha, only: %i[edit update]
  resources :funcoes, only: %i[index create destroy], param: :uuid do
    collection { patch :atualizar }
  end
  # What a cliente final sees by default, by kind (Etapa 2.8, 3a).
  resource :visibilidade, only: %i[edit update], controller: "visibilidade_padrao"
  # The dono's production parameters (Etapa 2.2, 1/3).
  resource :parametros, only: %i[edit update], controller: "parametros_empresa"
  get "lixeira" => "lixeira#index", as: :lixeira
  post "lixeira/:tipo/:id/restaurar" => "lixeira#restaurar", as: :restaurar_lixeira,
       constraints: { tipo: /arquivos|pedidos|clients|moldes|pecas|funcoes/ }
  get "up" => "rails/health#show", as: :rails_health_check

  resources :tamanhos, only: [] do
    member do
      get :download
      get :preview
    end
    collection do
      get :for_cascade
    end
  end

  resources :solicitacoes_aprovacao, only: [], param: :uuid, as: :solicitacoes do
    member { post :cancelar }
  end
  resources :aprovacoes, only: [], param: :uuid do
    member do
      post :cancelar
      get :anexo
    end
  end

  resources :arquivos, only: %i[index create show destroy] do
    # Referência + Nome of an arte (Etapa 1.1, 5/5).
    resource :nome_arte, only: :update, controller: "nomes_arte" do
      post :tornar_versao
    end
    # The arte's files, one per part × size (Etapa 1.2, 2/3).
    resource :arte, only: [], controller: "arte_arquivos" do
      post :acrescentar
      post :trazer
      post :separar
      post :tornar_piloto
      post :voltar_para_producao
      patch :definir_lado
    end
    # Etapa 2.5a: the arte's kind and the coleção geral.
    resource :tipo_da_arte, only: :update, controller: "tipos_da_arte" do
      patch :catalogo
      # Etapa 2.5b: a cor lisa's optional material.
      patch :material
      # Etapa 2.6a: a DTF's own space between copies on the film.
      patch :espacamento
    end
    # Etapa 2.6c: a DTF size's agreed unit price.
    resource :preco_dtf, only: :update, controller: "precos_da_etiqueta"
    resources :aprovacoes, only: %i[new create]
    resources :solicitacoes_aprovacao, only: :create, as: :solicitacoes
    # The cliente final's own answer (Etapa 2.8, 4a).
    post :aprovar_no_sistema, to: "resposta_do_cliente#aprovar"
    post :pedir_alteracao, to: "resposta_do_cliente#pedir_alteracao"
    member do
      patch :update_time
      patch :update_client
      patch :update_molde
      patch :update_tamanho
      patch :update_tipo_corte
      patch :update_giro
      post :add_molde
      delete :remove_molde
      get :preview
      get :composicao
      get :processamento
      get :busca_tamanho
      get :preparacao_tamanhos
      get :download
      post :upload_version
      patch :approve_version
      get :version_preview
      patch :configure_layers
      patch :organize
    end
    collection do
      delete :batch_destroy
      # Etapa 1.2 (2/3, parte 3): the upload's grouping, before anything is sent.
      post :agrupamento, to: "agrupamentos_upload#create"
    end
  end

  # The empty arte a group of the upload goes into (Etapa 1.2, 2/3 parte 3).
  resources :artes, only: :create, param: :uuid

  resources :clients, only: %i[show index create update destroy] do
    collection do
      get :search
    end
    # Etapa 2.8 (3a): this client's exceptions to the default visibility.
    member do
      patch :visibilidade, to: "visibilidade_do_cliente#update"
      # Etapa 2.6c: the DTF prices agreed with this client.
      patch :precos_dtf, to: "precos_dtf_do_cliente#update"
    end
  end

  # Official list, read only (Etapa 1.1, 3/5).
  resources :modelos, only: %i[index show] do
    collection do
      get :search
    end
  end

  resources :pecas, only: %i[index new create edit update destroy] do
    collection do
      get :search
      get :for_cascade
    end
  end

  resources :moldes, only: %i[index show create update destroy] do
    collection do
      get :search
      get :for_client
    end
    member do
      patch :update_peca_config
      post :adicionar_parte
      delete :remover_parte
    end
    # Etapa 2.4: the molde's price per pair by band of the grade.
    resources :faixas, controller: "faixas_de_preco", only: %i[create update destroy]
  end

  resources :materiais, only: %i[index new create update] do
    collection do
      get :grupos
      get :cores
      get :search
      post :create_grupo
      post :create_cor
    end
  end

  resources :movimentos, only: %i[index new create]

  # Etapa 2.5b: every cor lisa — the chart and the table.
  resources :cores, only: :index

  resources :pedidos, param: :uuid, only: %i[index show create update destroy] do
    collection do
      post :adicionar_item
      get :artes_para_adicionar
    end
    # Etapa 2.2 (2/3): the factory's baixa of a production stage.
    resources :baixas, only: %i[create destroy], controller: "baixas_producao"
    member do
      delete :remover_item
      patch :atualizar_item
      patch :alternar_peca
      get :corte
      get :baixar_corte
      get :impressao
      get :baixar_impressao
      # Etapa 2.2 (2/3): the pages of the stages without one of their own.
      get "etapas/:etapa", action: :etapa, as: :etapa
      # Etapa 2.2 (3/3): "Marcar como entregue".
      post :entregar
      # Etapa 2.2 (4/4): sends the open reposição to production early.
      post :gerar_reposicao
      post :confirmar
      # Etapa 2.8 (5/5): the client sends his draft and may take it back; the
      # team returns it with a note.
      post :enviar, to: "envios_pedido#enviar"
      post :retirar_envio, to: "envios_pedido#retirar"
      post :devolver, to: "envios_pedido#devolver"
      # Etapa 2.6b1: a DTF draft's delivery, extra rows and client.
      patch :dtf, to: "pedidos_dtf#update"
      patch "dtf/fileiras", to: "pedidos_dtf#fileiras", as: :dtf_fileiras
      # Etapa 2.6c: how it is charged and its edited prices.
      patch "dtf/precos", to: "precos_do_pedido_dtf#update", as: :dtf_precos
      patch "dtf/preco_linha", to: "precos_do_pedido_dtf#linha", as: :dtf_preco_linha
      get :resumo
    end
  end

  root "arquivos#index"

  match "/.well-known/*path", via: :all, to: proc { |_| [ 204, {}, [] ] }
end
