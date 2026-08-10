Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "roundabouts#index"

  resources :roundabouts, path: "ronds-points", only: %i[index show] do
    resources :photos, only: :create
    resources :votes, only: :create
  end

  get "palmares(/:year)", to: "palmares#show", as: :palmares, constraints: { year: /\d{4}/ }
end
