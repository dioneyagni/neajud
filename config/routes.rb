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
  get "lixeira" => "lixeira#index", as: :lixeira
  post "lixeira/:tipo/:id/restaurar" => "lixeira#restaurar", as: :restaurar_lixeira,
       constraints: { tipo: /arquivos|pedidos|clients|modelos|moldes|pecas|funcoes/ }
  get "up" => "rails/health#show", as: :rails_health_check

  resources :tamanhos, only: [] do
    member do
      get :download
    end
    collection do
      get :for_cascade
    end
  end

  resources :arquivos, only: %i[index create show destroy] do
    member do
      patch :update_time
      patch :update_client
      patch :update_modelo
      patch :update_tamanho
      patch :update_tipo_corte
      post :add_modelo
      delete :remove_modelo
      get :preview
      get :composicao
      get :processamento
      get :download
      post :upload_version
      patch :approve_version
      get :version_preview
      patch :configure_layers
      patch :organize
    end
    collection do
      delete :batch_destroy
    end
  end

  resources :clients, only: %i[show index create update destroy] do
    collection do
      get :search
    end
  end

  resources :moldes, only: %i[index show new create edit update destroy] do
    collection do
      get :search
    end
    member do
      get :pecas
    end
  end

  resources :pecas, only: %i[index new create edit update destroy] do
    collection do
      get :search
      get :for_cascade
    end
  end

  resources :modelos, only: %i[index show create update destroy] do
    collection do
      get :search
      get :for_client
    end
    member do
      patch :update_peca_config
    end
  end

  resources :materiais, only: %i[index new create] do
    collection do
      get :grupos
      get :cores
      get :search
      post :create_grupo
      post :create_cor
    end
  end

  resources :movimentos, only: %i[index new create]

  resources :pedidos, param: :uuid, only: %i[index show create update destroy] do
    collection do
      post :adicionar_item
    end
    member do
      delete :remover_item
      patch :atualizar_item
      patch :alternar_peca
      get :producao
      post :confirmar
      get :resumo
    end
    # Pending pieces of a draft pedido: choose an existing arte to complete them.
    resources :pecas, controller: "pedido_pecas", only: [] do
      member do
        get :escolher_arte
        post :vincular_arte
        post :enviar_arte
      end
    end
  end

  root "arquivos#index"

  match "/.well-known/*path", via: :all, to: proc { |_| [ 204, {}, [] ] }
end
