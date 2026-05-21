Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resources :tamanhos, only: [] do
    member do
      get :download
    end
  end

  resources :stamps, only: %i[index new create show destroy] do
    member do
      patch :update_time
      patch :update_client
      get :preview
      get :download
      post :upload_version
      patch :approve_version
      get :version_preview
      patch :configure_layers
      patch :organize
    end
  end

  resources :clients, only: %i[index create update destroy] do
    collection do
      get :search
    end
  end

  root "stamps#index"

  match "/.well-known/*path", via: :all, to: proc { |_| [ 204, {}, [] ] }
end
