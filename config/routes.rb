Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resources :tamanhos, only: [] do
    member do
      get :download
    end
    collection do
      get :for_cascade
    end
  end

  resources :arquivos, only: %i[index new create show destroy] do
    member do
      patch :update_time
      patch :update_client
      patch :update_modelo
      patch :update_tamanho
      get :preview
      get :download
      post :upload_version
      patch :approve_version
      get :version_preview
      patch :configure_layers
      patch :organize
    end
  end

  resources :clients, only: %i[show index create update destroy] do
    collection do
      get :search
    end
  end

  resources :moldes, only: %i[index show create update destroy] do
    collection do
      get :search
    end
    member do
      get :pecas
    end
  end

  resources :pecas, only: %i[index create update destroy] do
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
  end

  root "arquivos#index"

  match "/.well-known/*path", via: :all, to: proc { |_| [ 204, {}, [] ] }
end
