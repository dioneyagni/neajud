Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resources :stamps, only: %i[index new create show] do
    member do
      patch :update_time
      get :preview
    end
  end

  root "stamps#index"
end
